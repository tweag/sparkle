package io.tweag.sparkle.function;

import org.apache.spark.api.java.function.*;
import io.tweag.sparkle.Sparkle;
import java.util.Iterator;

public class HaskellMapPartitionsFunction<T, U> implements MapPartitionsFunction<T, U> {
  public final byte[] clos;

  public HaskellMapPartitionsFunction(final byte[] clos) {
	   this.clos = clos;
  }

  @Override
  public Iterator<U> call(Iterator<T> input) throws Exception {
	   return Sparkle.apply(clos, input);
  }
}
