import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import org.apache.spark.api.java.*;
import org.apache.spark.api.java.function.Function;
import org.apache.spark.sql.DataFrame;
import org.apache.spark.sql.SQLContext;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.RowFactory;
import org.apache.spark.sql.types.*;
import scala.Tuple2;

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

    public static JavaRDD<Row> toRows(JavaPairRDD<String, String> prdd)
    {
	JavaRDD<Row> res = prdd.map(new Function<Tuple2<String, String>, Row>() {
		public Row call(Tuple2<String, String> tup)
		{
		    return RowFactory.create(tup._1(), tup._2());
		}
	});
	return res;
    }

    public static DataFrame toDF(SQLContext ctx, JavaRDD<Row> rdd, String col1, String col2)
    {
	StructType st = new StructType();
	st.add(col1, DataTypes.StringType);
	st.add(col2, DataTypes.StringType);

	return ctx.createDataFrame(rdd, st);
    }
}
