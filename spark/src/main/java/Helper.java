import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import org.apache.spark.api.java.*;
import org.apache.spark.api.java.function.*;
import org.apache.spark.mllib.clustering.*;
import org.apache.spark.mllib.linalg.Vector;
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

    public static JavaPairRDD<Long, String> swapPairs(JavaPairRDD<String, Long> prdd)
    {
	return prdd.mapToPair(
	    new PairFunction<Tuple2<String, Long>, Long, String>() {
		public Tuple2<Long, String> call(Tuple2<String, Long> t)
		{
		    return new Tuple2<Long, String>(t._2(), t._1());
		}
	    });
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

    public static JavaRDD<Row> toRows(JavaPairRDD<Long, String> prdd)
    {
	JavaRDD<Row> res = prdd.map(new Function<Tuple2<Long, String>, Row>() {
		public Row call(Tuple2<Long, String> tup)
		{
		    return RowFactory.create(tup._1(), tup._2());
		}
	});
	return res;
    }

    public static DataFrame toDF(SQLContext ctx, JavaRDD<Row> rdd, String col1, String col2)
    {
	StructType st = new StructType();
	st.add(col1, DataTypes.LongType);
	st.add(col2, DataTypes.StringType);

	return ctx.createDataFrame(rdd, st);
    }

    public static JavaRDD<Row> fromDF(DataFrame df)
    {
        return df.toJavaRDD();
    }

    public static JavaPairRDD<Long, Vector> fromRows(JavaRDD<Row> rows)
    {
        JavaPairRDD<Long, Vector> res = rows.mapToPair(
	    new PairFunction<Row, Long, Vector>() {
		public Tuple2<Long, Vector> call(Row r)
		{
		    return new Tuple2<Long, Vector>((Long) r.get(0), (Vector) r.get(1));
		}
	    });
        return res.cache();
    }

    public static LDAModel runLDA(LDA l, JavaPairRDD<Long, Vector> docs)
    {
	return l.run(docs);
    }
}
