package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellFlatMapFunction<T, R>
    implements FlatMapFunction<T, R>
{
    private final byte[] clos;

    public HaskellFlatMapFunction(final byte[] clos) {
	this.clos = clos;
    }

    public Iterable<R> call(T value) throws Exception {
	return Sparkle.apply(clos, value);
    }
}
