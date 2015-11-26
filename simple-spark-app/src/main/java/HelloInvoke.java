/* SimpleApp.java */
import org.apache.spark.api.java.*;
import org.apache.spark.SparkConf;
import org.apache.spark.api.java.function.Function;
import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;

public class HelloInvoke {
  private native byte[] invokeHS(byte[] clos, int closLen, byte[] arg, int argLen);

  static {
      System.loadLibrary("HelloInvoke");
  }

  public static void main(String[] args) {
    String logFile = "./README.md"; // Should be some file on your system
    SparkConf conf = new SparkConf().setAppName("Simple Application");
    JavaSparkContext sc = new JavaSparkContext(conf);
    JavaRDD<String> logData = sc.textFile(logFile).cache();

    long numAs = logData.filter(new Function<String, Boolean>() {
      public Boolean call(String s) { return s.contains("a"); }
    }).count();

    long numBs = logData.filter(new Function<String, Boolean>() {
      public Boolean call(String s) {
        Path closPath = FileSystems.getDefault().getPath("./double.bin");
        Path argPath = FileSystems.getDefault().getPath("./arg_double.bin");
        Path resultPath = FileSystems.getDefault().getPath("result.bin");

        try {
            byte[] clos = Files.readAllBytes(closPath);
            byte[] arg = Files.readAllBytes(argPath);

            byte[] res = new HelloInvoke().invokeHS(clos, clos.length, arg, arg.length);
            Files.write(resultPath, res);

        } catch (IOException e) {
            System.out.println(e);
        }
        return s.contains("b");
      }
    }).count();

    System.out.println("Lines with a: " + numAs + ", lines with b: " + numBs);
  }
}
