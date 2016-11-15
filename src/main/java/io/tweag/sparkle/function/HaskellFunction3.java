package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellFunction3<T1, T2, T3, R> implements Function3<T1, T2, T3, R> {
    private final byte[] clos;

    public HaskellFunction3(final byte[] clos) {
	this.clos = clos;
    }

    public R call(T1 v1, T2 v2, T3 v3) throws Exception {
	return Sparkle.apply(clos, v1, v2, v3);
    }
}
