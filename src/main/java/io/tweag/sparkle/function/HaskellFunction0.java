package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellFunction0<R> implements Function0<R> {
    private final byte[] clos;

    public HaskellFunction0(final byte[] clos) {
	this.clos = clos;
    }

    public R call() throws Exception {
	return Sparkle.apply(clos);
    }
}
