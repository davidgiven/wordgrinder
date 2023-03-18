#include "Luau/ModuleResolver.h"
#include "Luau/TypeInfer.h"
#include "Luau/BuiltinDefinitions.h"
#include "Luau/Frontend.h"
#include "Luau/TypeAttach.h"
#include "Luau/Transpiler.h"
#include "assert.h"
#include <sstream>
#include <fstream>
#include <map>

static Luau::Config singletonConfig;

static int assertionHandler(
    const char* expr, const char* file, int line, const char* function)
{
    printf("%s(%d): ASSERTION FAILED: %s\n", file, line, expr);
    fflush(stdout);
    return 1;
}

class LocalFileResolver : public Luau::FileResolver
{
public:
    LocalFileResolver(const std::string& source): _source(source) {}

    std::optional<Luau::ModuleInfo> resolveModule(
        const Luau::ModuleInfo* context, Luau::AstExpr* expr) override
    {
        assert(false);
    }

    std::optional<Luau::SourceCode> readSource(
        const Luau::ModuleName& name) override
    {
        if (name != "main")
            return std::nullopt;

        return Luau::SourceCode{_source, Luau::SourceCode::Script};
    }

private:
    const std::string _source;
};

class LocalConfigResolver : public Luau::ConfigResolver
{
public:
    const Luau::Config& getConfig(const Luau::ModuleName& name) const override
    {
        return singletonConfig;
    }
};

int main(int argc, const char* argv[])
{
    int lineno = 1;
    std::multimap<int, std::string> fileLookup;
    std::stringstream ss;
    for (int i = 1; i < argc; i++)
    {
        fileLookup.emplace(lineno, argv[i]);

        std::ifstream f(argv[i]);
        if (!f)
            perror(argv[i]);

        char c;
        while (f.get(c))
        {
            if (c == '\n')
                lineno++;
            ss.put(c);
        }
    }

    Luau::assertHandler() = assertionHandler;

    Luau::FrontendOptions frontendOptions;

    LocalFileResolver fileResolver(ss.str());
    LocalConfigResolver configResolver;
    Luau::Frontend frontend(&fileResolver, &configResolver, frontendOptions);
    Luau::registerBuiltinGlobals(frontend.typeChecker, frontend.globals);

    Luau::CheckResult cr = frontend.check("main");
    for (auto& error : cr.errors)
    {
        auto i = fileLookup.lower_bound(error.location.begin.line);
        i--;
        std::string filename = i->second.c_str();
        int lineno = 2 + error.location.begin.line - i->first;

        printf("%s:%d: ", filename.c_str(), lineno);
        if (const auto* syntaxError =
                Luau::get_if<Luau::SyntaxError>(&error.data))
            printf("syntax error: %s\n", syntaxError->message.c_str());
        else
            printf("type error: %s\n",
                Luau::toString(error,
                    Luau::TypeErrorToStringOptions{frontend.fileResolver})
                    .c_str());
    }

    return 0;
}
