/* SimpleApp.java */
import org.apache.spark.api.java.*;
import org.apache.spark.SparkConf;
import org.apache.spark.api.java.function.Function;
import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;

public class HelloInvoke {

  public static void main(String[] args) {
    String logFile = "./README.md"; // Should be some file on your system
    SparkConf conf = new SparkConf().setAppName("Hello hs-invoke!");
    JavaSparkContext sc = new JavaSparkContext(conf);
    JavaRDD<String> logData = sc.textFile(logFile).cache();

    long numBs = logData.filter(new Function<String, Boolean>() {
      public Boolean call(String s) {
        Path resultPath = FileSystems.getDefault().getPath("./result.bin");

        try {
            // our serialized function, f x = x * 2, as an
            // array of bytes
            byte[] clos =
              { 0, 22, -98, -13
              , -40, 92, -87, 116
              , -56, -112, 123, -68
              , 126, -43, 43, 32
              , -61
              };

            // our serialized argument, 20
            byte[] arg = { 0, 0, 0, 0, 0, 0, 0, 20 };

            byte[] res = HaskellRTS.invokeHS(clos, clos.length, arg, arg.length);
            Files.write(resultPath, res);

        } catch (IOException e) {
            System.out.println(e);
        }
        return s.contains("b");
      }
    }).count();

    System.out.println("lines with b: " + numBs);
  }
}
