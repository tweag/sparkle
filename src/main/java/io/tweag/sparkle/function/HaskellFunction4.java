package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;

public class HaskellFunction4<T1, T2, T3, T4, R>
    implements Function4<T1, T2, T3, T4, R>
{
    private final byte[] clos;

    public HaskellFunction4(final byte[] clos) {
	this.clos = clos;
    }

    public R call(T1 v1, T2 v2, T3 v3, T4 v4) throws Exception {
	return Sparkle.apply(clos, v1, v2, v3, v4);
    }
}
