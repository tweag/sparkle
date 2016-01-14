import java.util.Arrays;
import java.util.List;
import org.apache.spark.api.java.*;

public class Helper
{
    public static JavaRDD<Integer>  parallelize
	(JavaSparkContext sc, int[] data)
    {
	if(data == null)
	    System.out.println("null!");
	System.out.println("hello from Helper.parallelize");
	Integer[] newArray = new Integer[data.length];
	for(int i = 0; i < data.length; i++)
	    newArray[i] = Integer.valueOf(data[i]);
	System.out.println("calling parallelize");

	List<Integer> arg = Arrays.asList(newArray);
	
        return sc.parallelize(arg);
    }
}
