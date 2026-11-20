/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source licence. See COPYING.
 */

package com.cowlark.wordgrinder.utils;

import org.jspecify.annotations.NonNull;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.function.ToIntFunction;

/**
 * Callback-driven command-line parsing, translated from ParseArguments in utils.lua.
 */
public final class ArgumentParser
{
    /* Store handlers independently for each parser; unhandled filenames are skipped. */
    private final @NonNull Map<@NonNull String,
            @NonNull ToIntFunction<@NonNull List<@NonNull String>>>
            callbacks = new HashMap<>();
    private @NonNull ToIntFunction<@NonNull List<@NonNull String>> filenameCallback = args -> 1;
    private @NonNull Consumer<@NonNull String> unknownCallback = option -> {
        throw new IllegalArgumentException("Unknown option: " + option);
    };

    private ArgumentParser()
    {
    }

    /**
     * Creates an independently configured argument parser.
     */
    public static @NonNull ArgumentParser builder()
    {
        return new ArgumentParser();
    }

    /* Model Lua's unpacked arguments with a stable snapshot, including an implicit first value. */
    private static @NonNull List<@NonNull String> prepend(
            @NonNull String first,
            @NonNull List<@NonNull String> remaining)
    {
        List<String> arguments = new ArrayList<>(remaining.size() + 1);
        arguments.add(first);
        arguments.addAll(remaining);
        return List.copyOf(arguments);
    }

    /**
     * Registers a handler for an option name without its leading dashes.
     */
    public @NonNull ArgumentParser onOption(
            @NonNull String option,
            @NonNull ToIntFunction<@NonNull List<@NonNull String>> callback)
    {
        callbacks.put(option, callback);
        return this;
    }

    /**
     * Registers a filename handler; by default each filename consumes one argument.
     */
    public @NonNull ArgumentParser onFilenames(
            @NonNull ToIntFunction<@NonNull List<@NonNull String>> callback)
    {
        filenameCallback = callback;
        return this;
    }

    /**
     * Registers an unknown-option handler; by default unknown options throw.
     */
    public @NonNull ArgumentParser onUnknownOption(@NonNull Consumer<@NonNull String> callback)
    {
        unknownCallback = callback;
        return this;
    }

    /**
     * Parses an argument array without modifying it. See the list overload for callback rules.
     * The array contains arguments only, excluding the executable name.
     */
    public void parse(@NonNull String @NonNull [] argv)
    {
        parse(new ArrayList<>(Arrays.asList(argv)));
    }

    /**
     * Consumes a mutable argument list using callbacks keyed by option name, without dashes.
     * Each callback receives an immutable snapshot of all remaining arguments and returns
     * the number it consumed. Flag options return zero. For -pvalue, value is prepended to
     * the callback's arguments; filenames are similarly prepended to filenameCallback's
     * arguments, so those callbacks must consume at least one argument.
     * <p>
     * Unknown options call unknownCallback with their name and stop parsing, leaving the
     * remaining list untouched. A negative consumption count throws IllegalArgumentException
     * (the Lua CLIError equivalent). Excess consumption simply empties the remaining list.
     */
    public void parse(@NonNull List<@NonNull String> argv)
    {
        /* Remove the current token before handing its remaining arguments to a callback. */
        while (!argv.isEmpty())
        {
            String option = argv.remove(0);
            long consumed;
            if (option.startsWith("-"))
            {
                boolean longOption = option.startsWith("--");
                String name = longOption ?
                        option.substring(2) :
                        option.length() > 1 ? option.substring(1, 2) : "";
                ToIntFunction<@NonNull List<@NonNull String>> callback = callbacks.get(name);
                if (callback == null)
                {
                    unknownCallback.accept(name);
                    return;
                }

                /* The suffix of a short option is a single attached argument, as in Lua. */
                String attached = !longOption && option.length() > 2 ? option.substring(2) : "";
                if (attached.isEmpty())
                    consumed = callback.applyAsInt(List.copyOf(argv));
                else
                    consumed = callback.applyAsInt(prepend(attached, argv)) - 1L;
            } else
                consumed = filenameCallback.applyAsInt(prepend(option, argv)) - 1L;

            /* Callback counts refer to arguments after the option token, excluding attachments. */
            if (consumed < 0)
                throw new IllegalArgumentException("malformed argument");
            argv.subList(0, (int) Math.min(consumed, argv.size())).clear();
        }
    }
}
