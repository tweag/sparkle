import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import org.apache.spark.api.java.*;

public class Helper
{
    public static JavaRDD<Integer> parallelize
	(JavaSparkContext sc, int[] data)
    {
	Integer[] newArray = new Integer[data.length];

	for(int i = 0; i < data.length; i++)
	{
	    newArray[i] = Integer.valueOf(data[i]);
	}

	List<Integer> arg = new ArrayList<Integer>(Arrays.asList(newArray));
	JavaRDD<Integer> rdd = sc.parallelize(arg);
        return rdd;
    }

    public static int[] collect(JavaRDD rdd)
    {
	List<Integer> l = rdd.collect();
	int[] res = new int[l.size()];
	for(int i = 0; i < l.size(); i++)
	    res[i] = l.get(i).intValue();
	return res;
    }
}
