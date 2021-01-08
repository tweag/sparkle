package io.tweag.sparkle;

/* The static initializer of the `Sparkle` class ensures that Haskell RTS is
 * properly initialized before any Haskell code is called (via the apply
 * method).
 */
public class Sparkle extends SparkleBase {
    static {
       String rtsOptsStr = System.getProperty("ghc_rts_opts", "");
       String rtsOpts[]  = {};
       if(!rtsOptsStr.isEmpty()) {
           rtsOpts = rtsOptsStr.split("\\s+");
       }
       initializeHaskellRTS(rtsOpts);
    }

    public static native <R> R apply(byte[] cos, Object... args);
    private static native void initializeHaskellRTS(String[] args);
    public static native void loadJavaWrappers();
}
