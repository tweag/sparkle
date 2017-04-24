package io.tweag.sparkle.kryo;

import com.esotericsoftware.kryo.Kryo;
import org.apache.spark.serializer.KryoRegistrator;
import io.tweag.sparkle.Sparkle;

/**
 * Register inline-java classes for Kryo serialization. Unlike other
 * registrators, calling this class is not just necessary for good
 * performance, it is necessary for correctness. Deserialization of
 * anonymous classes in inline-java quotes will fail without it.
 */
public class InlineJavaRegistrator implements KryoRegistrator {
    public void registerClasses(Kryo kryo) {
	Sparkle.loadJavaWrappers();
	// TODO actually register classes to make their encoding more
	// space efficient.
    }
}
