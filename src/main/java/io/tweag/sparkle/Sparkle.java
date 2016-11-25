package io.tweag.sparkle;

/* The static initializer of the `Sparkle` class ensures that Haskell RTS is
 * properly initialized before any Haskell code is called (via the apply
 * method).
 */
public class Sparkle extends SparkleBase {
    static {
        initializeHaskellRTS();
    }

    public static native <R> R apply(byte[] cos, Object... args);
    private static native void initializeHaskellRTS();
}
