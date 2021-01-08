package io.tweag.sparkle;

import java.util.Arrays;

/* The `SparkMain` clasess extends the `SparkleBase` class because the latter
 * ensures that the main() function of the Haskell program is loaded before
 * it is called by invokeMain(). Since main() is a Haskell program-created
 * function, it arranges for the initialization of the GHC RTS.
 */
public class SparkMain extends SparkleBase {
    private static native void invokeMain(String[] args);

    static <T> T[] arrayConcat(T[] a, T[] b) {
       final int alen = a.length;
       final int blen = b.length;
       final T[] result = (T[]) java.lang.reflect.Array.
            newInstance(a.getClass().getComponentType(), alen + blen);
       System.arraycopy(a, 0, result, 0, alen);
       System.arraycopy(b, 0, result, alen, blen);
       return result;
    }

    public static void main(String[] args) {
        String rtsOptsStr = System.getProperty("ghc_rts_opts", "");
        String rtsOpts[]  = {};
        if(!rtsOptsStr.isEmpty())
            rtsOpts = rtsOptsStr.split("\\s+");
        String allArgs[]  = arrayConcat(args, rtsOpts);
        invokeMain(allArgs);
    }
}
