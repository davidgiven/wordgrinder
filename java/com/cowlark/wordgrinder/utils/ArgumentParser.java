/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.utils;

import com.google.common.collect.ImmutableList;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Consumer;
import java.util.function.ToIntFunction;

/**
 * Callback-driven command-line parsing, translated from ParseArguments in utils.lua.
 */
public final class ArgumentParser
{
    /* Store handlers independently for each parser; unhandled filenames are skipped. */
    private final Map<String, ToIntFunction<ImmutableList<String>>> callbacks = new HashMap<>();
    private ToIntFunction<ImmutableList<String>> filenameCallback = args -> 1;
    private Consumer<String> unknownCallback = option -> {
        throw new IllegalArgumentException("Unknown option: " + option);
    };

    private ArgumentParser()
    {
    }

    /**
     * Creates an independently configured argument parser.
     */
    public static ArgumentParser builder()
    {
        return new ArgumentParser();
    }

    /* Model Lua's unpacked arguments with a stable snapshot, including an implicit first value. */
    private static ImmutableList<String> prepend(String first, ImmutableList<String> remaining)
    {
        return ImmutableList.<String>builder()
                .add(first).addAll(remaining).build();
    }

    /**
     * Registers a handler for an option name without its leading dashes.
     */
    public ArgumentParser onOption(String option, ToIntFunction<ImmutableList<String>> callback)
    {
        callbacks.put(option, callback);
        return this;
    }

    /**
     * Registers a filename handler; by default each filename consumes one argument.
     */
    public ArgumentParser onFilenames(
            ToIntFunction<ImmutableList<String>> callback)
    {
        filenameCallback = callback;
        return this;
    }

    /**
     * Registers an unknown-option handler; by default unknown options throw.
     */
    public ArgumentParser onUnknownOption(Consumer<String> callback)
    {
        unknownCallback = callback;
        return this;
    }

    /**
     * Parses an immutable argument list using callbacks keyed by option name, without dashes.
     * The list excludes the executable name and is never modified.
     * Each callback receives an immutable snapshot of all remaining arguments and returns
     * the number it consumed. Flag options return zero. For -pvalue, value is prepended to
     * the callback's arguments; filenames are similarly prepended to filenameCallback's
     * arguments, so those callbacks must consume at least one argument.
     * <p>
     * Unknown options call unknownCallback with their name and stop parsing, leaving the
     * input unchanged. A negative consumption count throws IllegalArgumentException
     * (the Lua CLIError equivalent). Excess consumption stops at the end of the input.
     */
    public void parse(ImmutableList<String> argv)
    {
        /* Advance a local cursor while callbacks receive immutable views of the remaining input. */
        int position = 0;
        while (position < argv.size())
        {
            String option = argv.get(position++);
            ImmutableList<String> remaining = argv.subList(position, argv.size());
            long consumed;
            if (option.startsWith("-"))
            {
                boolean longOption = option.startsWith("--");
                String name = longOption ?
                        option.substring(2) :
                        option.length() > 1 ? option.substring(1, 2) : "";
                ToIntFunction<ImmutableList<String>> callback = callbacks.get(name);
                if (callback == null)
                {
                    unknownCallback.accept(name);
                    return;
                }

                /* The suffix of a short option is a single attached argument, as in Lua. */
                String attached = !longOption && option.length() > 2 ? option.substring(2) : "";
                if (attached.isEmpty())
                    consumed = callback.applyAsInt(remaining);
                else
                    consumed = callback.applyAsInt(prepend(attached, remaining)) - 1L;
            } else
                consumed = filenameCallback.applyAsInt(prepend(option, remaining)) - 1L;

            /* Callback counts refer to arguments after the option token, excluding attachments. */
            if (consumed < 0)
                throw new IllegalArgumentException("malformed argument");
            position += (int) Math.min(consumed, argv.size() - position);
        }
    }
}
