// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#include "Luau/Frontend.h"

#include "Luau/BuiltinDefinitions.h"
#include "Luau/Clone.h"
#include "Luau/Common.h"
#include "Luau/Config.h"
#include "Luau/ConstraintGraphBuilder.h"
#include "Luau/ConstraintSolver.h"
#include "Luau/DataFlowGraph.h"
#include "Luau/DcrLogger.h"
#include "Luau/FileResolver.h"
#include "Luau/Parser.h"
#include "Luau/Scope.h"
#include "Luau/StringUtils.h"
#include "Luau/TimeTrace.h"
#include "Luau/TypeChecker2.h"
#include "Luau/TypeInfer.h"
#include "Luau/TypeReduction.h"
#include "Luau/Variant.h"

#include <algorithm>
#include <chrono>
#include <stdexcept>
#include <string>

LUAU_FASTINT(LuauTypeInferIterationLimit)
LUAU_FASTINT(LuauTypeInferRecursionLimit)
LUAU_FASTINT(LuauTarjanChildLimit)
LUAU_FASTFLAG(LuauInferInNoCheckMode)
LUAU_FASTFLAGVARIABLE(LuauKnowsTheDataModel3, false)
LUAU_FASTINTVARIABLE(LuauAutocompleteCheckTimeoutMs, 100)
LUAU_FASTFLAGVARIABLE(DebugLuauDeferredConstraintResolution, false)
LUAU_FASTFLAGVARIABLE(DebugLuauLogSolverToJson, false)
LUAU_FASTFLAG(LuauRequirePathTrueModuleName)
LUAU_FASTFLAGVARIABLE(DebugLuauReadWriteProperties, false)

namespace Luau
{

std::optional<Mode> parseMode(const std::vector<HotComment>& hotcomments)
{
    for (const HotComment& hc : hotcomments)
    {
        if (!hc.header)
            continue;

        if (hc.content == "nocheck")
            return Mode::NoCheck;

        if (hc.content == "nonstrict")
            return Mode::Nonstrict;

        if (hc.content == "strict")
            return Mode::Strict;
    }

    return std::nullopt;
}

static void generateDocumentationSymbols(TypeId ty, const std::string& rootName)
{
    // TODO: What do we do in this situation? This means that the definition
    // file is exporting a type that is also a persistent type.
    if (ty->persistent)
    {
        return;
    }

    asMutable(ty)->documentationSymbol = rootName;

    if (TableType* ttv = getMutable<TableType>(ty))
    {
        for (auto& [name, prop] : ttv->props)
        {
            prop.documentationSymbol = rootName + "." + name;
        }
    }
    else if (ClassType* ctv = getMutable<ClassType>(ty))
    {
        for (auto& [name, prop] : ctv->props)
        {
            prop.documentationSymbol = rootName + "." + name;
        }
    }
}

static ParseResult parseSourceForModule(std::string_view source, Luau::SourceModule& sourceModule, bool captureComments)
{
    ParseOptions options;
    options.allowDeclarationSyntax = true;
    options.captureComments = captureComments;

    Luau::ParseResult parseResult = Luau::Parser::parse(source.data(), source.size(), *sourceModule.names, *sourceModule.allocator, options);
    sourceModule.root = parseResult.root;
    sourceModule.mode = Mode::Definition;
    return parseResult;
}

static void persistCheckedTypes(ModulePtr checkedModule, GlobalTypes& globals, ScopePtr targetScope, const std::string& packageName)
{
    CloneState cloneState;

    std::vector<TypeId> typesToPersist;
    typesToPersist.reserve(checkedModule->declaredGlobals.size() + checkedModule->exportedTypeBindings.size());

    for (const auto& [name, ty] : checkedModule->declaredGlobals)
    {
        TypeId globalTy = clone(ty, globals.globalTypes, cloneState);
        std::string documentationSymbol = packageName + "/global/" + name;
        generateDocumentationSymbols(globalTy, documentationSymbol);
        targetScope->bindings[globals.globalNames.names->getOrAdd(name.c_str())] = {globalTy, Location(), false, {}, documentationSymbol};

        typesToPersist.push_back(globalTy);
    }

    for (const auto& [name, ty] : checkedModule->exportedTypeBindings)
    {
        TypeFun globalTy = clone(ty, globals.globalTypes, cloneState);
        std::string documentationSymbol = packageName + "/globaltype/" + name;
        generateDocumentationSymbols(globalTy.type, documentationSymbol);
        targetScope->exportedTypeBindings[name] = globalTy;

        typesToPersist.push_back(globalTy.type);
    }

    for (TypeId ty : typesToPersist)
    {
        persist(ty);
    }
}

LoadDefinitionFileResult Frontend::loadDefinitionFile(GlobalTypes& globals, ScopePtr targetScope, std::string_view source,
    const std::string& packageName, bool captureComments, bool typeCheckForAutocomplete)
{
    LUAU_TIMETRACE_SCOPE("loadDefinitionFile", "Frontend");

    Luau::SourceModule sourceModule;
    Luau::ParseResult parseResult = parseSourceForModule(source, sourceModule, captureComments);
    if (parseResult.errors.size() > 0)
        return LoadDefinitionFileResult{false, parseResult, sourceModule, nullptr};

    ModulePtr checkedModule = check(sourceModule, Mode::Definition, {}, std::nullopt, /*forAutocomplete*/ false, /*recordJsonLog*/ false, {});

    if (checkedModule->errors.size() > 0)
        return LoadDefinitionFileResult{false, parseResult, sourceModule, checkedModule};

    persistCheckedTypes(checkedModule, globals, targetScope, packageName);

    return LoadDefinitionFileResult{true, parseResult, sourceModule, checkedModule};
}

std::vector<std::string_view> parsePathExpr(const AstExpr& pathExpr)
{
    const AstExprIndexName* indexName = pathExpr.as<AstExprIndexName>();
    if (!indexName)
        return {};

    std::vector<std::string_view> segments{indexName->index.value};

    while (true)
    {
        if (AstExprIndexName* in = indexName->expr->as<AstExprIndexName>())
        {
            segments.push_back(in->index.value);
            indexName = in;
            continue;
        }
        else if (AstExprGlobal* indexNameAsGlobal = indexName->expr->as<AstExprGlobal>())
        {
            segments.push_back(indexNameAsGlobal->name.value);
            break;
        }
        else if (AstExprLocal* indexNameAsLocal = indexName->expr->as<AstExprLocal>())
        {
            segments.push_back(indexNameAsLocal->local->name.value);
            break;
        }
        else
            return {};
    }

    std::reverse(segments.begin(), segments.end());
    return segments;
}

std::optional<std::string> pathExprToModuleName(const ModuleName& currentModuleName, const std::vector<std::string_view>& segments)
{
    if (segments.empty())
        return std::nullopt;

    std::vector<std::string_view> result;

    auto it = segments.begin();

    if (*it == "script" && !currentModuleName.empty())
    {
        result = split(currentModuleName, '/');
        ++it;
    }

    for (; it != segments.end(); ++it)
    {
        if (result.size() > 1 && *it == "Parent")
            result.pop_back();
        else
            result.push_back(*it);
    }

    return join(result, "/");
}

std::optional<std::string> pathExprToModuleName(const ModuleName& currentModuleName, const AstExpr& pathExpr)
{
    std::vector<std::string_view> segments = parsePathExpr(pathExpr);
    return pathExprToModuleName(currentModuleName, segments);
}

namespace
{

static ErrorVec accumulateErrors(
    const std::unordered_map<ModuleName, SourceNode>& sourceNodes, ModuleResolver& moduleResolver, const ModuleName& name)
{
    std::unordered_set<ModuleName> seen;
    std::vector<ModuleName> queue{name};

    ErrorVec result;

    while (!queue.empty())
    {
        ModuleName next = std::move(queue.back());
        queue.pop_back();

        if (seen.count(next))
            continue;
        seen.insert(next);

        auto it = sourceNodes.find(next);
        if (it == sourceNodes.end())
            continue;

        const SourceNode& sourceNode = it->second;
        queue.insert(queue.end(), sourceNode.requireSet.begin(), sourceNode.requireSet.end());

        // FIXME: If a module has a syntax error, we won't be able to re-report it here.
        // The solution is probably to move errors from Module to SourceNode

        auto modulePtr = moduleResolver.getModule(next);
        if (!modulePtr)
            continue;

        Module& module = *modulePtr;

        std::sort(module.errors.begin(), module.errors.end(), [](const TypeError& e1, const TypeError& e2) -> bool {
            return e1.location.begin > e2.location.begin;
        });

        result.insert(result.end(), module.errors.begin(), module.errors.end());
    }

    std::reverse(result.begin(), result.end());

    return result;
}

static void filterLintOptions(LintOptions& lintOptions, const std::vector<HotComment>& hotcomments, Mode mode)
{
    uint64_t ignoreLints = LintWarning::parseMask(hotcomments);

    lintOptions.warningMask &= ~ignoreLints;

    if (mode != Mode::NoCheck)
    {
        lintOptions.disableWarning(Luau::LintWarning::Code_UnknownGlobal);
    }

    if (mode == Mode::Strict)
    {
        lintOptions.disableWarning(Luau::LintWarning::Code_ImplicitReturn);
    }
}

// Given a source node (start), find all requires that start a transitive dependency path that ends back at start
// For each such path, record the full path and the location of the require in the starting module.
// Note that this is O(V^2) for a fully connected graph and produces O(V) paths of length O(V)
// However, when the graph is acyclic, this is O(V), as well as when only the first cycle is needed (stopAtFirst=true)
std::vector<RequireCycle> getRequireCycles(
    const FileResolver* resolver, const std::unordered_map<ModuleName, SourceNode>& sourceNodes, const SourceNode* start, bool stopAtFirst = false)
{
    std::vector<RequireCycle> result;

    DenseHashSet<const SourceNode*> seen(nullptr);
    std::vector<const SourceNode*> stack;
    std::vector<const SourceNode*> path;

    for (const auto& [depName, depLocation] : start->requireLocations)
    {
        std::vector<ModuleName> cycle;

        auto dit = sourceNodes.find(depName);
        if (dit == sourceNodes.end())
            continue;

        stack.push_back(&dit->second);

        while (!stack.empty())
        {
            const SourceNode* top = stack.back();
            stack.pop_back();

            if (top == nullptr)
            {
                // special marker for post-order processing
                LUAU_ASSERT(!path.empty());
                top = path.back();
                path.pop_back();

                // we reached the node! path must form a cycle now
                if (top == start)
                {
                    for (const SourceNode* node : path)
                        cycle.push_back(FFlag::LuauRequirePathTrueModuleName ? node->name : node->humanReadableName);

                    cycle.push_back(FFlag::LuauRequirePathTrueModuleName ? top->name : top->humanReadableName);
                    break;
                }
            }
            else if (!seen.contains(top))
            {
                seen.insert(top);

                // push marker for post-order processing
                path.push_back(top);
                stack.push_back(nullptr);

                // note: we push require edges in the opposite order
                // because it's a stack, the last edge to be pushed gets processed first
                // this ensures that the cyclic path we report is the first one in DFS order
                for (size_t i = top->requireLocations.size(); i > 0; --i)
                {
                    const ModuleName& reqName = top->requireLocations[i - 1].first;

                    auto rit = sourceNodes.find(reqName);
                    if (rit != sourceNodes.end())
                        stack.push_back(&rit->second);
                }
            }
        }

        path.clear();
        stack.clear();

        if (!cycle.empty())
        {
            result.push_back({depLocation, std::move(cycle)});

            if (stopAtFirst)
                return result;

            // note: if we didn't find a cycle, all nodes that we've seen don't depend [transitively] on start
            // so it's safe to *only* clear seen vector when we find a cycle
            // if we don't do it, we will not have correct reporting for some cycles
            seen.clear();
        }
    }

    return result;
}

double getTimestamp()
{
    using namespace std::chrono;
    return double(duration_cast<nanoseconds>(high_resolution_clock::now().time_since_epoch()).count()) / 1e9;
}

} // namespace

Frontend::Frontend(FileResolver* fileResolver, ConfigResolver* configResolver, const FrontendOptions& options)
    : builtinTypes(NotNull{&builtinTypes_})
    , fileResolver(fileResolver)
    , moduleResolver(this)
    , moduleResolverForAutocomplete(this)
    , globals(builtinTypes)
    , globalsForAutocomplete(builtinTypes)
    , configResolver(configResolver)
    , options(options)
{
}

CheckResult Frontend::check(const ModuleName& name, std::optional<FrontendOptions> optionOverride)
{
    LUAU_TIMETRACE_SCOPE("Frontend::check", "Frontend");
    LUAU_TIMETRACE_ARGUMENT("name", name.c_str());

    FrontendOptions frontendOptions = optionOverride.value_or(options);
    CheckResult checkResult;

    FrontendModuleResolver& resolver = frontendOptions.forAutocomplete ? moduleResolverForAutocomplete : moduleResolver;

    auto it = sourceNodes.find(name);
    if (it != sourceNodes.end() && !it->second.hasDirtyModule(frontendOptions.forAutocomplete))
    {
        // No recheck required.
        ModulePtr module = resolver.getModule(name);

        if (!module)
            throw InternalCompilerError("Frontend::modules does not have data for " + name, name);

        checkResult.errors = accumulateErrors(sourceNodes, resolver, name);

        // Get lint result only for top checked module
        checkResult.lintResult = module->lintResult;

        return checkResult;
    }

    std::vector<ModuleName> buildQueue;
    bool cycleDetected = parseGraph(buildQueue, name, frontendOptions.forAutocomplete);

    for (const ModuleName& moduleName : buildQueue)
    {
        LUAU_ASSERT(sourceNodes.count(moduleName));
        SourceNode& sourceNode = sourceNodes[moduleName];

        if (!sourceNode.hasDirtyModule(frontendOptions.forAutocomplete))
            continue;

        LUAU_ASSERT(sourceModules.count(moduleName));
        SourceModule& sourceModule = sourceModules[moduleName];

        const Config& config = configResolver->getConfig(moduleName);

        Mode mode = sourceModule.mode.value_or(config.mode);

        ScopePtr environmentScope = getModuleEnvironment(sourceModule, config, frontendOptions.forAutocomplete);

        double timestamp = getTimestamp();

        std::vector<RequireCycle> requireCycles;

        // in NoCheck mode we only need to compute the value of .cyclic for typeck
        // in the future we could replace toposort with an algorithm that can flag cyclic nodes by itself
        // however, for now getRequireCycles isn't expensive in practice on the cases we care about, and long term
        // all correct programs must be acyclic so this code triggers rarely
        if (cycleDetected)
            requireCycles = getRequireCycles(fileResolver, sourceNodes, &sourceNode, mode == Mode::NoCheck);

        // This is used by the type checker to replace the resulting type of cyclic modules with any
        sourceModule.cyclic = !requireCycles.empty();

        if (frontendOptions.forAutocomplete)
        {
            double autocompleteTimeLimit = FInt::LuauAutocompleteCheckTimeoutMs / 1000.0;

            // The autocomplete typecheck is always in strict mode with DM awareness
            // to provide better type information for IDE features
            TypeCheckLimits typeCheckLimits;

            if (autocompleteTimeLimit != 0.0)
                typeCheckLimits.finishTime = TimeTrace::getClock() + autocompleteTimeLimit;
            else
                typeCheckLimits.finishTime = std::nullopt;

            // TODO: This is a dirty ad hoc solution for autocomplete timeouts
            // We are trying to dynamically adjust our existing limits to lower total typechecking time under the limit
            // so that we'll have type information for the whole file at lower quality instead of a full abort in the middle
            if (FInt::LuauTarjanChildLimit > 0)
                typeCheckLimits.instantiationChildLimit = std::max(1, int(FInt::LuauTarjanChildLimit * sourceNode.autocompleteLimitsMult));
            else
                typeCheckLimits.instantiationChildLimit = std::nullopt;

            if (FInt::LuauTypeInferIterationLimit > 0)
                typeCheckLimits.unifierIterationLimit = std::max(1, int(FInt::LuauTypeInferIterationLimit * sourceNode.autocompleteLimitsMult));
            else
                typeCheckLimits.unifierIterationLimit = std::nullopt;

            ModulePtr moduleForAutocomplete = check(sourceModule, Mode::Strict, requireCycles, environmentScope, /*forAutocomplete*/ true,
                /*recordJsonLog*/ false, typeCheckLimits);

            resolver.setModule(moduleName, moduleForAutocomplete);

            double duration = getTimestamp() - timestamp;

            if (moduleForAutocomplete->timeout)
            {
                checkResult.timeoutHits.push_back(moduleName);

                sourceNode.autocompleteLimitsMult = sourceNode.autocompleteLimitsMult / 2.0;
            }
            else if (duration < autocompleteTimeLimit / 2.0)
            {
                sourceNode.autocompleteLimitsMult = std::min(sourceNode.autocompleteLimitsMult * 2.0, 1.0);
            }

            stats.timeCheck += duration;
            stats.filesStrict += 1;

            sourceNode.dirtyModuleForAutocomplete = false;
            continue;
        }

        const bool recordJsonLog = FFlag::DebugLuauLogSolverToJson && moduleName == name;
        ModulePtr module = check(sourceModule, mode, requireCycles, environmentScope, /*forAutocomplete*/ false, recordJsonLog, {});

        stats.timeCheck += getTimestamp() - timestamp;
        stats.filesStrict += mode == Mode::Strict;
        stats.filesNonstrict += mode == Mode::Nonstrict;

        if (module == nullptr)
            throw InternalCompilerError("Frontend::check produced a nullptr module for " + moduleName, moduleName);

        if (FFlag::DebugLuauDeferredConstraintResolution && mode == Mode::NoCheck)
            module->errors.clear();

        if (frontendOptions.runLintChecks)
        {
            LUAU_TIMETRACE_SCOPE("lint", "Frontend");

            LintOptions lintOptions = frontendOptions.enabledLintWarnings.value_or(config.enabledLint);
            filterLintOptions(lintOptions, sourceModule.hotcomments, mode);

            double timestamp = getTimestamp();

            std::vector<LintWarning> warnings =
                Luau::lint(sourceModule.root, *sourceModule.names, environmentScope, module.get(), sourceModule.hotcomments, lintOptions);

            stats.timeLint += getTimestamp() - timestamp;

            module->lintResult = classifyLints(warnings, config);
        }

        if (!frontendOptions.retainFullTypeGraphs)
        {
            // copyErrors needs to allocate into interfaceTypes as it copies
            // types out of internalTypes, so we unfreeze it here.
            unfreeze(module->interfaceTypes);
            copyErrors(module->errors, module->interfaceTypes);
            freeze(module->interfaceTypes);

            module->internalTypes.clear();

            module->astTypes.clear();
            module->astTypePacks.clear();
            module->astExpectedTypes.clear();
            module->astOriginalCallTypes.clear();
            module->astOverloadResolvedTypes.clear();
            module->astResolvedTypes.clear();
            module->astOriginalResolvedTypes.clear();
            module->astResolvedTypePacks.clear();
            module->astScopes.clear();

            module->scopes.clear();
        }

        if (mode != Mode::NoCheck)
        {
            for (const RequireCycle& cyc : requireCycles)
            {
                TypeError te{cyc.location, moduleName, ModuleHasCyclicDependency{cyc.path}};

                module->errors.push_back(te);
            }
        }

        ErrorVec parseErrors;

        for (const ParseError& pe : sourceModule.parseErrors)
            parseErrors.push_back(TypeError{pe.getLocation(), moduleName, SyntaxError{pe.what()}});

        module->errors.insert(module->errors.begin(), parseErrors.begin(), parseErrors.end());

        checkResult.errors.insert(checkResult.errors.end(), module->errors.begin(), module->errors.end());

        resolver.setModule(moduleName, std::move(module));
        sourceNode.dirtyModule = false;
    }

    // Get lint result only for top checked module
    if (ModulePtr module = resolver.getModule(name))
        checkResult.lintResult = module->lintResult;

    return checkResult;
}

bool Frontend::parseGraph(std::vector<ModuleName>& buildQueue, const ModuleName& root, bool forAutocomplete)
{
    LUAU_TIMETRACE_SCOPE("Frontend::parseGraph", "Frontend");
    LUAU_TIMETRACE_ARGUMENT("root", root.c_str());

    // https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search
    enum Mark
    {
        None,
        Temporary,
        Permanent
    };

    DenseHashMap<SourceNode*, Mark> seen(nullptr);
    std::vector<SourceNode*> stack;
    std::vector<SourceNode*> path;
    bool cyclic = false;

    {
        auto [sourceNode, _] = getSourceNode(root);
        if (sourceNode)
            stack.push_back(sourceNode);
    }

    while (!stack.empty())
    {
        SourceNode* top = stack.back();
        stack.pop_back();

        if (top == nullptr)
        {
            // special marker for post-order processing
            LUAU_ASSERT(!path.empty());

            top = path.back();
            path.pop_back();

            // note: topseen ref gets invalidated in any seen[] access, beware - only one seen[] access per iteration!
            Mark& topseen = seen[top];
            LUAU_ASSERT(topseen == Temporary);
            topseen = Permanent;

            buildQueue.push_back(top->name);
        }
        else
        {
            // note: topseen ref gets invalidated in any seen[] access, beware - only one seen[] access per iteration!
            Mark& topseen = seen[top];

            if (topseen != None)
            {
                cyclic |= topseen == Temporary;
                continue;
            }

            topseen = Temporary;

            // push marker for post-order processing
            stack.push_back(nullptr);
            path.push_back(top);

            // push children
            for (const ModuleName& dep : top->requireSet)
            {
                auto it = sourceNodes.find(dep);
                if (it != sourceNodes.end())
                {
                    // this is a critical optimization: we do *not* traverse non-dirty subtrees.
                    // this relies on the fact that markDirty marks reverse-dependencies dirty as well
                    // thus if a node is not dirty, all its transitive deps aren't dirty, which means that they won't ever need
                    // to be built, *and* can't form a cycle with any nodes we did process.
                    if (!it->second.hasDirtyModule(forAutocomplete))
                        continue;

                    // note: this check is technically redundant *except* that getSourceNode has somewhat broken memoization
                    // calling getSourceNode twice in succession will reparse the file, since getSourceNode leaves dirty flag set
                    if (seen.contains(&it->second))
                    {
                        stack.push_back(&it->second);
                        continue;
                    }
                }

                auto [sourceNode, _] = getSourceNode(dep);
                if (sourceNode)
                {
                    stack.push_back(sourceNode);

                    // note: this assignment is paired with .contains() check above and effectively deduplicates getSourceNode()
                    seen[sourceNode] = None;
                }
            }
        }
    }

    return cyclic;
}

ScopePtr Frontend::getModuleEnvironment(const SourceModule& module, const Config& config, bool forAutocomplete) const
{
    ScopePtr result;
    if (forAutocomplete)
        result = globalsForAutocomplete.globalScope;
    else
        result = globals.globalScope;

    if (module.environmentName)
        result = getEnvironmentScope(*module.environmentName);

    if (!config.globals.empty())
    {
        result = std::make_shared<Scope>(result);

        for (const std::string& global : config.globals)
        {
            AstName name = module.names->get(global.c_str());

            if (name.value)
                result->bindings[name].typeId = builtinTypes->anyType;
        }
    }

    return result;
}

bool Frontend::isDirty(const ModuleName& name, bool forAutocomplete) const
{
    auto it = sourceNodes.find(name);
    return it == sourceNodes.end() || it->second.hasDirtyModule(forAutocomplete);
}

/*
 * Mark a file as requiring rechecking before its type information can be safely used again.
 *
 * I am not particularly pleased with the way each dirty() operation involves a BFS on reverse dependencies.
 * It would be nice for this function to be O(1)
 */
void Frontend::markDirty(const ModuleName& name, std::vector<ModuleName>* markedDirty)
{
    if (!moduleResolver.getModule(name) && !moduleResolverForAutocomplete.getModule(name))
        return;

    std::unordered_map<ModuleName, std::vector<ModuleName>> reverseDeps;
    for (const auto& module : sourceNodes)
    {
        for (const auto& dep : module.second.requireSet)
            reverseDeps[dep].push_back(module.first);
    }

    std::vector<ModuleName> queue{name};

    while (!queue.empty())
    {
        ModuleName next = std::move(queue.back());
        queue.pop_back();

        LUAU_ASSERT(sourceNodes.count(next) > 0);
        SourceNode& sourceNode = sourceNodes[next];

        if (markedDirty)
            markedDirty->push_back(next);

        if (sourceNode.dirtySourceModule && sourceNode.dirtyModule && sourceNode.dirtyModuleForAutocomplete)
            continue;

        sourceNode.dirtySourceModule = true;
        sourceNode.dirtyModule = true;
        sourceNode.dirtyModuleForAutocomplete = true;

        if (0 == reverseDeps.count(next))
            continue;

        sourceModules.erase(next);

        const std::vector<ModuleName>& dependents = reverseDeps[next];
        queue.insert(queue.end(), dependents.begin(), dependents.end());
    }
}

SourceModule* Frontend::getSourceModule(const ModuleName& moduleName)
{
    auto it = sourceModules.find(moduleName);
    if (it != sourceModules.end())
        return &it->second;
    else
        return nullptr;
}

const SourceModule* Frontend::getSourceModule(const ModuleName& moduleName) const
{
    return const_cast<Frontend*>(this)->getSourceModule(moduleName);
}

ModulePtr check(const SourceModule& sourceModule, const std::vector<RequireCycle>& requireCycles, NotNull<BuiltinTypes> builtinTypes,
    NotNull<InternalErrorReporter> iceHandler, NotNull<ModuleResolver> moduleResolver, NotNull<FileResolver> fileResolver,
    const ScopePtr& parentScope, std::function<void(const ModuleName&, const ScopePtr&)> prepareModuleScope, FrontendOptions options)
{
    const bool recordJsonLog = FFlag::DebugLuauLogSolverToJson;
    return check(sourceModule, requireCycles, builtinTypes, iceHandler, moduleResolver, fileResolver, parentScope, std::move(prepareModuleScope),
        options, recordJsonLog);
}

ModulePtr check(const SourceModule& sourceModule, const std::vector<RequireCycle>& requireCycles, NotNull<BuiltinTypes> builtinTypes,
    NotNull<InternalErrorReporter> iceHandler, NotNull<ModuleResolver> moduleResolver, NotNull<FileResolver> fileResolver,
    const ScopePtr& parentScope, std::function<void(const ModuleName&, const ScopePtr&)> prepareModuleScope, FrontendOptions options,
    bool recordJsonLog)
{
    ModulePtr result = std::make_shared<Module>();
    result->name = sourceModule.name;
    result->humanReadableName = sourceModule.humanReadableName;
    result->reduction = std::make_unique<TypeReduction>(NotNull{&result->internalTypes}, builtinTypes, iceHandler);

    std::unique_ptr<DcrLogger> logger;
    if (recordJsonLog)
    {
        logger = std::make_unique<DcrLogger>();
        std::optional<SourceCode> source = fileResolver->readSource(result->name);
        if (source)
        {
            logger->captureSource(source->source);
        }
    }

    DataFlowGraph dfg = DataFlowGraphBuilder::build(sourceModule.root, iceHandler);

    UnifierSharedState unifierState{iceHandler};
    unifierState.counters.recursionLimit = FInt::LuauTypeInferRecursionLimit;
    unifierState.counters.iterationLimit = FInt::LuauTypeInferIterationLimit;

    Normalizer normalizer{&result->internalTypes, builtinTypes, NotNull{&unifierState}};

    ConstraintGraphBuilder cgb{
        result,
        &result->internalTypes,
        moduleResolver,
        builtinTypes,
        iceHandler,
        parentScope,
        std::move(prepareModuleScope),
        logger.get(),
        NotNull{&dfg},
    };

    cgb.visit(sourceModule.root);
    result->errors = std::move(cgb.errors);

    ConstraintSolver cs{
        NotNull{&normalizer}, NotNull(cgb.rootScope), borrowConstraints(cgb.constraints), result->name, moduleResolver, requireCycles, logger.get()};

    if (options.randomizeConstraintResolutionSeed)
        cs.randomize(*options.randomizeConstraintResolutionSeed);

    cs.run();

    for (TypeError& e : cs.errors)
        result->errors.emplace_back(std::move(e));

    result->scopes = std::move(cgb.scopes);
    result->type = sourceModule.type;

    result->clonePublicInterface(builtinTypes, *iceHandler);

    Luau::check(builtinTypes, NotNull{&unifierState}, logger.get(), sourceModule, result.get());

    // Ideally we freeze the arenas before the call into Luau::check, but TypeReduction
    // needs to allocate new types while Luau::check is in progress, so here we are.
    //
    // It does mean that mutations to the type graph can happen after the constraints
    // have been solved, which will cause hard-to-debug problems. We should revisit this.
    freeze(result->internalTypes);
    freeze(result->interfaceTypes);

    if (recordJsonLog)
    {
        std::string output = logger->compileOutput();
        printf("%s\n", output.c_str());
    }

    return result;
}

ModulePtr Frontend::check(const SourceModule& sourceModule, Mode mode, std::vector<RequireCycle> requireCycles,
    std::optional<ScopePtr> environmentScope, bool forAutocomplete, bool recordJsonLog, TypeCheckLimits typeCheckLimits)
{
    if (FFlag::DebugLuauDeferredConstraintResolution && mode == Mode::Strict)
    {
        auto prepareModuleScopeWrap = [this, forAutocomplete](const ModuleName& name, const ScopePtr& scope) {
            if (prepareModuleScope)
                prepareModuleScope(name, scope, forAutocomplete);
        };

        return Luau::check(sourceModule, requireCycles, builtinTypes, NotNull{&iceHandler},
            NotNull{forAutocomplete ? &moduleResolverForAutocomplete : &moduleResolver}, NotNull{fileResolver},
            environmentScope ? *environmentScope : globals.globalScope, prepareModuleScopeWrap, options, recordJsonLog);
    }
    else
    {
        TypeChecker typeChecker(globals.globalScope, forAutocomplete ? &moduleResolverForAutocomplete : &moduleResolver, builtinTypes, &iceHandler);

        if (prepareModuleScope)
        {
            typeChecker.prepareModuleScope = [this, forAutocomplete](const ModuleName& name, const ScopePtr& scope) {
                prepareModuleScope(name, scope, forAutocomplete);
            };
        }

        typeChecker.requireCycles = requireCycles;
        typeChecker.finishTime = typeCheckLimits.finishTime;
        typeChecker.instantiationChildLimit = typeCheckLimits.instantiationChildLimit;
        typeChecker.unifierIterationLimit = typeCheckLimits.unifierIterationLimit;

        return typeChecker.check(sourceModule, mode, environmentScope);
    }
}

// Read AST into sourceModules if necessary.  Trace require()s.  Report parse errors.
std::pair<SourceNode*, SourceModule*> Frontend::getSourceNode(const ModuleName& name)
{
    LUAU_TIMETRACE_SCOPE("Frontend::getSourceNode", "Frontend");
    LUAU_TIMETRACE_ARGUMENT("name", name.c_str());

    auto it = sourceNodes.find(name);
    if (it != sourceNodes.end() && !it->second.hasDirtySourceModule())
    {
        auto moduleIt = sourceModules.find(name);
        if (moduleIt != sourceModules.end())
            return {&it->second, &moduleIt->second};
        else
        {
            LUAU_ASSERT(!"Everything in sourceNodes should also be in sourceModules");
            return {&it->second, nullptr};
        }
    }

    double timestamp = getTimestamp();

    std::optional<SourceCode> source = fileResolver->readSource(name);
    std::optional<std::string> environmentName = fileResolver->getEnvironmentForModule(name);

    stats.timeRead += getTimestamp() - timestamp;

    if (!source)
    {
        sourceModules.erase(name);
        return {nullptr, nullptr};
    }

    const Config& config = configResolver->getConfig(name);
    ParseOptions opts = config.parseOptions;
    opts.captureComments = true;
    SourceModule result = parse(name, source->source, opts);
    result.type = source->type;

    RequireTraceResult& require = requireTrace[name];
    require = traceRequires(fileResolver, result.root, name);

    SourceNode& sourceNode = sourceNodes[name];
    SourceModule& sourceModule = sourceModules[name];

    sourceModule = std::move(result);
    sourceModule.environmentName = environmentName;

    sourceNode.name = sourceModule.name;
    sourceNode.humanReadableName = sourceModule.humanReadableName;
    sourceNode.requireSet.clear();
    sourceNode.requireLocations.clear();
    sourceNode.dirtySourceModule = false;

    if (it == sourceNodes.end())
    {
        sourceNode.dirtyModule = true;
        sourceNode.dirtyModuleForAutocomplete = true;
    }

    for (const auto& [moduleName, location] : require.requireList)
        sourceNode.requireSet.insert(moduleName);

    sourceNode.requireLocations = require.requireList;

    return {&sourceNode, &sourceModule};
}

/** Try to parse a source file into a SourceModule.
 *
 * The logic here is a little bit more complicated than we'd like it to be.
 *
 * If a file does not exist, we return none to prevent the Frontend from creating knowledge that this module exists.
 * If the Frontend thinks that the file exists, it will not produce an "Unknown require" error.
 *
 * If the file has syntax errors, we report them and synthesize an empty AST if it's not available.
 * This suppresses the Unknown require error and allows us to make a best effort to typecheck code that require()s
 * something that has broken syntax.
 * We also translate Luau::ParseError into a Luau::TypeError so that we can use a vector<TypeError> to describe the
 * result of the check()
 */
SourceModule Frontend::parse(const ModuleName& name, std::string_view src, const ParseOptions& parseOptions)
{
    LUAU_TIMETRACE_SCOPE("Frontend::parse", "Frontend");
    LUAU_TIMETRACE_ARGUMENT("name", name.c_str());

    SourceModule sourceModule;

    double timestamp = getTimestamp();

    Luau::ParseResult parseResult = Luau::Parser::parse(src.data(), src.size(), *sourceModule.names, *sourceModule.allocator, parseOptions);

    stats.timeParse += getTimestamp() - timestamp;
    stats.files++;
    stats.lines += parseResult.lines;

    if (!parseResult.errors.empty())
        sourceModule.parseErrors.insert(sourceModule.parseErrors.end(), parseResult.errors.begin(), parseResult.errors.end());

    if (parseResult.errors.empty() || parseResult.root)
    {
        sourceModule.root = parseResult.root;
        sourceModule.mode = parseMode(parseResult.hotcomments);
    }
    else
    {
        sourceModule.root = sourceModule.allocator->alloc<AstStatBlock>(Location{}, AstArray<AstStat*>{nullptr, 0});
        sourceModule.mode = Mode::NoCheck;
    }

    sourceModule.name = name;
    sourceModule.humanReadableName = fileResolver->getHumanReadableModuleName(name);

    if (parseOptions.captureComments)
    {
        sourceModule.commentLocations = std::move(parseResult.commentLocations);
        sourceModule.hotcomments = std::move(parseResult.hotcomments);
    }

    return sourceModule;
}


FrontendModuleResolver::FrontendModuleResolver(Frontend* frontend)
    : frontend(frontend)
{
}

std::optional<ModuleInfo> FrontendModuleResolver::resolveModuleInfo(const ModuleName& currentModuleName, const AstExpr& pathExpr)
{
    // FIXME I think this can be pushed into the FileResolver.
    auto it = frontend->requireTrace.find(currentModuleName);
    if (it == frontend->requireTrace.end())
    {
        // CLI-43699
        // If we can't find the current module name, that's because we bypassed the frontend's initializer
        // and called typeChecker.check directly.
        // In that case, requires will always fail.
        return std::nullopt;
    }

    const auto& exprs = it->second.exprs;

    const ModuleInfo* info = exprs.find(&pathExpr);
    if (!info)
        return std::nullopt;

    return *info;
}

const ModulePtr FrontendModuleResolver::getModule(const ModuleName& moduleName) const
{
    std::scoped_lock lock(moduleMutex);

    auto it = modules.find(moduleName);
    if (it != modules.end())
        return it->second;
    else
        return nullptr;
}

bool FrontendModuleResolver::moduleExists(const ModuleName& moduleName) const
{
    return frontend->sourceNodes.count(moduleName) != 0;
}

std::string FrontendModuleResolver::getHumanReadableModuleName(const ModuleName& moduleName) const
{
    return frontend->fileResolver->getHumanReadableModuleName(moduleName);
}

void FrontendModuleResolver::setModule(const ModuleName& moduleName, ModulePtr module)
{
    std::scoped_lock lock(moduleMutex);

    modules[moduleName] = std::move(module);
}

void FrontendModuleResolver::clearModules()
{
    std::scoped_lock lock(moduleMutex);

    modules.clear();
}

ScopePtr Frontend::addEnvironment(const std::string& environmentName)
{
    LUAU_ASSERT(environments.count(environmentName) == 0);

    if (environments.count(environmentName) == 0)
    {
        ScopePtr scope = std::make_shared<Scope>(globals.globalScope);
        environments[environmentName] = scope;
        return scope;
    }
    else
        return environments[environmentName];
}

ScopePtr Frontend::getEnvironmentScope(const std::string& environmentName) const
{
    if (auto it = environments.find(environmentName); it != environments.end())
        return it->second;

    LUAU_ASSERT(!"environment doesn't exist");
    return {};
}

void Frontend::registerBuiltinDefinition(const std::string& name, std::function<void(Frontend&, GlobalTypes&, ScopePtr)> applicator)
{
    LUAU_ASSERT(builtinDefinitions.count(name) == 0);

    if (builtinDefinitions.count(name) == 0)
        builtinDefinitions[name] = applicator;
}

void Frontend::applyBuiltinDefinitionToEnvironment(const std::string& environmentName, const std::string& definitionName)
{
    LUAU_ASSERT(builtinDefinitions.count(definitionName) > 0);

    if (builtinDefinitions.count(definitionName) > 0)
        builtinDefinitions[definitionName](*this, globals, getEnvironmentScope(environmentName));
}

LintResult Frontend::classifyLints(const std::vector<LintWarning>& warnings, const Config& config)
{
    LintResult result;
    for (const auto& w : warnings)
    {
        if (config.lintErrors || config.fatalLint.isEnabled(w.code))
            result.errors.push_back(w);
        else
            result.warnings.push_back(w);
    }

    return result;
}

void Frontend::clearStats()
{
    stats = {};
}

void Frontend::clear()
{
    sourceNodes.clear();
    sourceModules.clear();
    moduleResolver.clearModules();
    moduleResolverForAutocomplete.clearModules();
    requireTrace.clear();
}

} // namespace Luau