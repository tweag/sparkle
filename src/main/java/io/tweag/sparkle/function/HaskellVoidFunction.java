package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellVoidFunction<T> implements VoidFunction<T> {
    private final byte[] clos;

    public HaskellVoidFunction(final byte[] clos) {
	this.clos = clos;
    }

    public void call(T v1) throws Exception {
	Sparkle.apply(clos, v1);
    }
}
