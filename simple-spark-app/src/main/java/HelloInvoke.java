import com.upokecenter.cbor.CBORObject;
import java.io.ByteArrayOutputStream;
import java.io.OutputStream;
import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;
import org.apache.spark.api.java.*;
import org.apache.spark.SparkConf;
import org.apache.spark.api.java.function.Function;

public class HelloInvoke {

  public static void main(String[] args) {
    SparkConf conf = new SparkConf().setAppName("Hello RDD!");
    JavaSparkContext sc = new JavaSparkContext(conf);

    List<Integer> dat = Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    JavaRDD<Integer> data = sc.parallelize(dat);

    List<Integer> newData = data.map(new Function<Integer, Integer>() {
      public Integer call(Integer i) throws IOException {
        // our serialized function, from hs-invoke/Simple.hs, as an
        // array of bytes
        byte[] clos =
          { 0, -77, 40, -28
          , 55, -69, -39, -22
          , 70, 56, 26, 29
          , -22, 79, -87, 77
          , 85 };

          ByteArrayOutputStream baos = new ByteArrayOutputStream();
          CBORObject.Write(i.intValue(), baos);
          byte[] arg = baos.toByteArray();

          byte[] res = HaskellRTS.invokeHS(clos, clos.length, arg, arg.length);

          Integer result = new Integer(CBORObject.DecodeFromBytes(res).AsInt32());
          return result;
      }
    }).toArray();

    System.out.println(Arrays.toString(newData.toArray()));
  }
}
