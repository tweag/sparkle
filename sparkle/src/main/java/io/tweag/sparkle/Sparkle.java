package io.tweag.sparkle;

public class Sparkle {
    static {
	System.out.println("Loading Sparkle application ...");
	System.loadLibrary("hsapp");
	System.out.println("Application loaded.");
    }

    public static native void bootstrap();

    private static native void initializeHaskellRTS();
    private static native void finalizeHaskellRTS();

    public static native <R> R apply(byte[] cos, Object... args);
    public static native void invoke(byte[] cos, Object... args);
}
