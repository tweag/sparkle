package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellFunction<T1, R> implements Function<T1, R> {
    public final byte[] clos;

    public HaskellFunction(final byte[] clos) {
	this.clos = clos;
    }

    public R call(T1 v1) throws Exception {
	return Sparkle.apply(clos, v1);
    }
}
