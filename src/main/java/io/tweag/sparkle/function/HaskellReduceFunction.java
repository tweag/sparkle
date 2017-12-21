package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;
import java.util.Iterator;

public class HaskellReduceFunction<T> implements ReduceFunction<T> {
  public final byte[] clos;

  public HaskellReduceFunction(final byte[] clos) {
	   this.clos = clos;
  }

  @Override
  public T call(T a, T b) throws Exception {
	   return Sparkle.apply(clos, a, b);
  }
}
