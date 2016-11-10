package io.tweag.sparkle;

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.Enumeration;
import java.util.zip.*;

public class Sparkle {
    static {
	System.out.println("Loading Sparkle application ...");
	try {
	    loadApplication(extractResource("/app.zip"), "hsapp");
	} catch (Exception e) {
	    System.out.println(e);
            throw new ExceptionInInitializerError(e);
        }
	System.out.println("Application loaded.");
	Sparkle.initializeHaskellRTS();
    }

    public static Path extractResource(String name) throws IOException {
	InputStream in = Sparkle.class.getResourceAsStream(name);
	File temp = File.createTempFile(name, "");

	Files.copy(in, temp.toPath(), StandardCopyOption.REPLACE_EXISTING);
	in.close();

	return temp.toPath();
    }

    public static void loadApplication(Path archive, String appName) throws IOException {
	ZipFile zip = new ZipFile(archive.toFile());
	String tmp = System.getProperty("java.io.tmpdir");
	Path dir = Files.createTempDirectory(Paths.get(tmp), "sparkle-app");

	for(Enumeration e = zip.entries(); e.hasMoreElements();) {
	    ZipEntry entry = (ZipEntry)e.nextElement();
	    InputStream in = zip.getInputStream(entry);
	    Path path = dir.resolve(entry.getName());
	    Files.copy(in, path);
	    in.close();
	}

	zip.close();
	System.load(dir.resolve(appName).toString());
    }

    public static native void bootstrap();
    public static native <R> R apply(byte[] cos, Object... args);
    private static native void initializeHaskellRTS();
}
