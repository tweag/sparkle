import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import org.apache.spark.api.java.*;
import org.apache.spark.api.java.function.Function;

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

    public static int[] collect(JavaRDD<Integer> rdd)
    {
	List<Integer> l = rdd.collect();
	int[] res = new int[l.size()];
	for(int i = 0; i < l.size(); i++)
	    res[i] = l.get(i).intValue();
	return res;
    }

    public static JavaRDD<Integer> map(JavaRDD<Integer> rdd, final byte[] clos)
    {
	JavaRDD<Integer> newRDD = rdd.map(new Function<Integer, Integer>() {
		public Integer call(Integer arg)
		{
		    return new Integer(HaskellRTS.invoke(clos, arg.intValue()));
		}
	});
	return newRDD;
    }
}
