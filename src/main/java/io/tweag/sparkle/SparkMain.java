package io.tweag.sparkle;

/* The `SparkMain` clasess extends the `SparkleBase` class because the latter
 * ensures that the main() function of the Haskell program is loaded before
 * it is called by invokeMain(). Since main() is a Haskell program-created
 * function, it arranges for the initialization of the GHC RTS.
 */
public class SparkMain extends SparkleBase {
    private static native void invokeMain(String[] args);
    public static void main(String[] args) {
        invokeMain(args);
    }
}
