package com.cowlark.wordgrinder.teavm;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Arrays;
import org.teavm.backend.c.CTarget;
import org.teavm.backend.c.generate.CNameProvider;
import org.teavm.backend.c.generate.SimpleFileNameProvider;
import org.teavm.tooling.ConsoleTeaVMToolLog;
import org.teavm.tooling.TeaVMProblemRenderer;
import org.teavm.vm.TeaVMBuilder;
import org.teavm.vm.TeaVMOptimizationLevel;

/** Generates C for the native WordGrinder build. */
public final class TeaVMCDriver
{
    public static void main(String[] args) throws IOException
    {
        if (args.length < 2)
            throw new IllegalArgumentException("Usage: TeaVMCDriver <main class> <shard>...");

        /* Configure the C backend with the existing optimisation level. */
        var target = new CTarget(new CNameProvider());
        target.setFileNames(new SimpleFileNameProvider());
        target.setObfuscated(false);
        var vm = new TeaVMBuilder(target).setObfuscated(false).build();
        vm.setOptimizationLevel(TeaVMOptimizationLevel.SIMPLE);

        /* Discover the compiler extensions on the driver classpath and emit C. */
        vm.installPlugins();
        vm.setEntryPoint(args[0]);
        var output = new ShardedCOutput();
        vm.build(output, "all.c");

        /* Report compiler diagnostics and fail the build on errors. */
        TeaVMProblemRenderer.describeProblems(vm, new ConsoleTeaVMToolLog(false));
        if (!vm.getProblemProvider().getSevereProblems().isEmpty())
            System.exit(1);

        /* Write the declared shards after successful code generation. */
        output.writeShards(Arrays.stream(args).skip(1).map(Path::of).toList());
    }
}
