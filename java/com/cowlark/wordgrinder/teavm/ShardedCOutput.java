package com.cowlark.wordgrinder.teavm;

import static java.nio.charset.StandardCharsets.UTF_8;

import java.io.BufferedWriter;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.teavm.vm.BuildTarget;

/** Captures generated resources and writes self-contained C translation units. */
final class ShardedCOutput implements BuildTarget
{
    /* Recognise the generated directives that affect include expansion. */
    private static final Pattern DIRECTIVE = Pattern.compile("^\\s*#\\s*(\\w+)\\s*(.*)");
    private static final Pattern QUOTED_HEADER = Pattern.compile("^\"([^\"]+)\"");
    private static final Pattern INNER_CLASS = Pattern.compile("@d|\\$");
    private static final HexFormat HEX = HexFormat.of().withUpperCase();

    private final Map<Path, ByteArrayOutputStream> resources = new HashMap<>();
    private final MessageDigest digest = sha256();

    /* Collect each named resource as TeaVM emits it. */
    @Override
    public OutputStream createResource(String name)
    {
        var output = new ByteArrayOutputStream();
        resources.put(Path.of(name).normalize(), output);
        return output;
    }

    /* Group the sources deterministically and emit every declared shard. */
    void writeShards(List<Path> outputs) throws IOException
    {
        var prologue = new StringBuilder();
        for (String line : lines(Path.of("all.c")))
        {
            if (line.startsWith("#define "))
            {
                String name = line.split("\\s+", 3)[1];
                prologue.append("#ifndef ").append(name).append('\n')
                        .append(line).append("\n#endif\n");
            }
        }

        /* Sort the manifest so enumeration order cannot affect any shard. */
        var shards = new ArrayList<List<Path>>(outputs.size());
        for (Path output : outputs)
            shards.add(new ArrayList<>());
        for (String name : lines(Path.of("all.txt")).stream().filter(s -> !s.isEmpty()).sorted().toList())
        {
            Path source = Path.of(name);
            int index = Byte.toUnsignedInt(hash(shardKey(source))[0]) % shards.size();
            shards.get(index).add(source);
        }

        /* Keep include tracking local to each translation unit. */
        for (int index = 0; index < outputs.size(); index++)
        {
            try (var writer = Files.newBufferedWriter(outputs.get(index), UTF_8))
            {
                writer.write(prologue.toString());
                var seen = new HashSet<Path>();
                var active = new HashSet<Path>();
                for (Path source : shards.get(index))
                    expand(source, writer, seen, active, true);
            }
        }
    }

    /* TeaVM escapes the JVM's dollar sign as @d in generated filenames. */
    private static String shardKey(Path source)
    {
        if (!source.startsWith("classes"))
            return portableName(source);

        String filename = source.getFileName().toString();
        int extension = filename.lastIndexOf('.');
        var inner = INNER_CLASS.matcher(filename.substring(0, extension));
        if (inner.find())
            source = source.resolveSibling(filename.substring(0, inner.start()) + filename.substring(extension));
        return portableName(source);
    }

    /* Replace pragma once with a guard that works even inside conditional includes. */
    private void expand(Path source, BufferedWriter writer, Set<Path> seen, Set<Path> active,
            boolean unconditional) throws IOException
    {
        if (seen.contains(source))
            return;

        List<String> lines = lines(source);
        boolean once = lines.stream().anyMatch(line -> line.strip().equals("#pragma once"));
        if (!active.add(source))
        {
            if (once)
                return;
            throw new IOException("Recursive generated include in " + source);
        }
        if (once && unconditional)
            seen.add(source);

        String name = portableName(source);
        String guard = once ? "WG_TEAVM_" + HEX.formatHex(hash(name)) : "";
        if (once)
            writer.write("#ifndef " + guard + "\n#define " + guard + "\n");
        writeLineMarker(writer, 1, name);

        /* Expand generated includes and leave external headers to the C compiler. */
        int depth = 0;
        for (int index = 0; index < lines.size(); index++)
        {
            String line = lines.get(index);
            var directive = DIRECTIVE.matcher(line);
            if (directive.matches())
            {
                String kind = directive.group(1);
                String argument = directive.group(2);
                switch (kind)
                {
                    case "if", "ifdef", "ifndef" -> depth++;
                    case "endif" -> depth--;
                    case "pragma" -> {
                        if (argument.strip().equals("once"))
                            line = "";
                    }
                    case "include" -> {
                        var header = QUOTED_HEADER.matcher(argument);
                        if (header.find())
                        {
                            Path included = resolveInclude(source, Path.of(header.group(1)));
                            if (included != null)
                            {
                                expand(included, writer, seen, active, unconditional && depth == 0);
                                writeLineMarker(writer, index + 2, name);
                                continue;
                            }
                        }
                    }
                    default -> { }
                }
            }
            writer.write(line);
            writer.write('\n');
        }

        /* Close the generated guard and remove the file from the include stack. */
        if (once)
            writer.write("#endif\n");
        active.remove(source);
    }

    /* Search beside the includer first, then in the generated root. */
    private Path resolveInclude(Path source, Path header)
    {
        Path adjacent = source.resolveSibling(header).normalize();
        if (resources.containsKey(adjacent))
            return adjacent;
        Path relative = header.normalize();
        return resources.containsKey(relative) ? relative : null;
    }

    /* Keep the original file and line visible in diagnostics and debugging information. */
    private static void writeLineMarker(BufferedWriter writer, int line, String name) throws IOException
    {
        String quoted = name.replace("\\", "\\\\").replace("\"", "\\\"")
                .replace("\t", "\\t");
        writer.write("#line " + line + " \"" + quoted + "\"\n");
    }

    private List<String> lines(Path source) throws IOException
    {
        var data = resources.get(source);
        if (data == null)
            throw new IOException("Missing generated resource " + source);
        return data.toString(UTF_8).lines().toList();
    }

    private static String portableName(Path source)
    {
        return source.toString().replace(java.io.File.separatorChar, '/');
    }

    private byte[] hash(String text)
    {
        return digest.digest(text.getBytes(UTF_8));
    }

    private static MessageDigest sha256()
    {
        try
        {
            return MessageDigest.getInstance("SHA-256");
        }
        catch (NoSuchAlgorithmException e)
        {
            throw new AssertionError(e);
        }
    }
}
