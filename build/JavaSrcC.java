import javax.tools.FileObject;
import javax.tools.ForwardingJavaFileManager;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileManager;
import javax.tools.JavaFileObject;
import javax.tools.SimpleJavaFileObject;
import javax.tools.StandardJavaFileManager;
import javax.tools.StandardLocation;
import javax.tools.ToolProvider;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.StringWriter;
import java.io.Writer;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarOutputStream;
import java.util.stream.Stream;

public class JavaSrcC {
    public static void main(String[] args) {
        if (args.length == 0) {
            System.err.println("Usage: java JavacSrcJarToJar.java -o <output.jar> "
                    + "[javac options] <sources.srcjar|*.java>");
            return;
        }

        String outputJarPath = null;
        List<String> javacOptions = new ArrayList<>();
        List<JavaFileObject> compilationUnits = new ArrayList<>();
        List<FileSystem> openFileSystems = new ArrayList<>();

        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        StandardJavaFileManager standardFileManager =
                compiler.getStandardFileManager(null, null, null);

        for (int i = 0; i < args.length; i++) {
            // Inside the for-loop filtering arguments:
            if ("-d".equals(args[i]) || "-s".equals(args[i])) {
                System.err.println("Warning: Ignoring flag '" + args[i] +
                        "'. Output location is determined by -o.");
                i++; // Skip the directory path argument following the flag
            }

            if ("-o".equals(args[i]) && i + 1 < args.length) {
                outputJarPath = args[++i];
            } else if (args[i].endsWith(".srcjar")) {
                File file = new File(args[i]);
                if (!file.exists()) {
                    System.err.println("Error: file not found: " + args[i]);
                    System.exit(1);
                }
                try {
                    URI zipUri = URI.create("jar:" + file.toURI());
                    FileSystem fs =
                            FileSystems.newFileSystem(zipUri, Collections.emptyMap());
                    openFileSystems.add(fs);

                    for (Path root : fs.getRootDirectories()) {
                        try (Stream<Path> stream = Files.walk(root)) {
                            stream.filter(p -> p.toString().endsWith(".java"))
                                    .map(VirtualInputJavaFileObject::new)
                                    .forEach(compilationUnits::add);
                        }
                    }
                } catch (IOException e) {
                    System.err.println("Error reading srcjar: " + e.getMessage());
                    System.exit(1);
                }
            } else if (args[i].endsWith(".java")) {
                standardFileManager.getJavaFileObjects(args[i]).forEach(
                        compilationUnits::add);
            } else {
                javacOptions.add(args[i]);
            }
        }

        if (outputJarPath == null || compilationUnits.isEmpty()) {
            System.err.println("Error: Missing required parameters.");
            System.exit(1);
        }

        // Storage for ALL compiled and generated classes
        Map<String, MemoryOutputJavaFileObject> compiledClasses =
                new LinkedHashMap<>();
        // Storage for generated source files (.java) from annotation processors
        Map<String, MemorySourceJavaFileObject> generatedSources =
                new LinkedHashMap<>();

        try (
                JavaFileManager customFileManager = new CapturingJavaFileManager(
                        standardFileManager, compiledClasses, generatedSources)) {

            // Run the compiler task. Javac internally manages the annotation
            // processing rounds, feeding generated sources back into subsequent
            // compilation rounds automatically.
            boolean success = compiler
                    .getTask(null, customFileManager, null,
                            javacOptions, null, compilationUnits)
                    .call();

            if (success) {
                try (JarOutputStream jos = new JarOutputStream(new BufferedOutputStream(
                        new FileOutputStream(outputJarPath)))) {
                    for (Map.Entry<String, MemoryOutputJavaFileObject> entry :
                            compiledClasses.entrySet()) {
                        String internalPath = entry.getKey().replace('.', '/') + ".class";
                        JarEntry jarEntry = new JarEntry(internalPath);
                        jos.putNextEntry(jarEntry);
                        jos.write(entry.getValue().getByteCode());
                        jos.closeEntry();
                    }
                }
            }
            System.exit(success ? 0 : 1);

        } catch (IOException e) {
            System.err.println("I/O Error: " + e.getMessage());
            System.exit(1);
        } finally {
            for (FileSystem fs : openFileSystems) {
                try {
                    fs.close();
                } catch (IOException ignored) {
                }
            }
        }
    }

    private static class CapturingJavaFileManager
            extends ForwardingJavaFileManager<StandardJavaFileManager> {
        private final Map<String, MemoryOutputJavaFileObject> compiledClasses;
        private final Map<String, MemorySourceJavaFileObject> generatedSources;

        protected CapturingJavaFileManager(
                StandardJavaFileManager fileManager,
                Map<String, MemoryOutputJavaFileObject> compiledClasses,
                Map<String, MemorySourceJavaFileObject> generatedSources) {
            super(fileManager);
            this.compiledClasses = compiledClasses;
            this.generatedSources = generatedSources;
        }

        @Override
        public JavaFileObject
        getJavaFileForOutput(Location location, String className,
                             JavaFileObject.Kind kind, FileObject sibling)
                throws IOException {
            // Catch standard compiled classes AND classes generated by annotation
            // processors
            if (kind == JavaFileObject.Kind.CLASS) {
                MemoryOutputJavaFileObject memoryFile =
                        new MemoryOutputJavaFileObject(className);
                compiledClasses.put(className, memoryFile);
                return memoryFile;
            }

            // Catch .java source files generated by annotation processors
            if (kind == JavaFileObject.Kind.SOURCE &&
                    location == StandardLocation.SOURCE_OUTPUT) {
                MemorySourceJavaFileObject sourceFile =
                        new MemorySourceJavaFileObject(className);
                generatedSources.put(className, sourceFile);
                return sourceFile;
            }

            return super.getJavaFileForOutput(location, className, kind, sibling);
        }
    }


    private static class VirtualInputJavaFileObject extends SimpleJavaFileObject {
        private final Path path;

        protected VirtualInputJavaFileObject(Path path) {
            // Super expects a hierarchical URI so uri.getPath() isn't null.
            // We construct a fake 'srcjar:///' schema using the internal archive path.
            super(createHierarchicalUri(path), Kind.SOURCE);
            this.path = path;
        }

        private static URI createHierarchicalUri(Path path) {
            String cleanPath = path.toString().replace('\\', '/');
            if (cleanPath.startsWith("/")) {
                cleanPath = cleanPath.substring(1);
            }
            return URI.create("srcjar:///" + cleanPath);
        }

        @Override
        public CharSequence getCharContent(boolean ignoreEncodingErrors) throws IOException {
            return Files.readString(path);
        }
    }

    private static class MemoryOutputJavaFileObject extends SimpleJavaFileObject {
        private final ByteArrayOutputStream baos = new ByteArrayOutputStream();

        protected MemoryOutputJavaFileObject(String className) {
            super(URI.create("mem:///" + className.replace('.', '/') +
                            Kind.CLASS.extension),
                    Kind.CLASS);
        }

        @Override
        public OutputStream openOutputStream() {
            return baos;
        }

        public byte[] getByteCode() {
            return baos.toByteArray();
        }
    }

    private static class MemorySourceJavaFileObject extends SimpleJavaFileObject {
        private final StringWriter writer = new StringWriter();

        protected MemorySourceJavaFileObject(String className) {
            super(URI.create("mem:///" + className.replace('.', '/') +
                            Kind.SOURCE.extension),
                    Kind.SOURCE);
        }

        @Override
        public Writer openWriter() {
            return writer;
        }

        @Override
        public CharSequence getCharContent(boolean ignoreEncodingErrors) {
            return writer.toString();
        }
    }
}