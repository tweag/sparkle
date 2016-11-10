package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellFunction2<T1, T2, R>
    implements Function2<T1, T2, R>
{
    private final byte[] clos;

    public HaskellFunction2(final byte[] clos) {
	this.clos = clos;
    }

    public R call(T1 v1, T2 v2) throws Exception {
	return Sparkle.apply(clos, v1, v2);
    }
}
