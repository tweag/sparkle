import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import org.apache.spark.api.java.*;
import org.apache.spark.api.java.function.*;
import org.apache.spark.ml.feature.*;
import org.apache.spark.mllib.clustering.*;
import org.apache.spark.mllib.linalg.Vector;
import org.apache.spark.sql.DataFrame;
import org.apache.spark.sql.SQLContext;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.RowFactory;
import org.apache.spark.sql.types.*;
import org.apache.spark.sql.functions;
import scala.Tuple2;

public class Helper {
    public static RegexTokenizer setupTokenizer(RegexTokenizer rt, String icol, String ocol, boolean gaps, String patt) {
	return rt.setInputCol(icol)
	         .setOutputCol(ocol)
	         .setGaps(gaps)
	         .setPattern(patt)
	         .setMinTokenLength(5);
    }

    public static JavaRDD<Row> toRows(JavaPairRDD<String, Long> prdd) {
	JavaRDD<Row> res = prdd.map(new Function<Tuple2<String, Long>, Row>() {
		public Row call(Tuple2<String, Long> tup) {
		    return RowFactory.create(tup._2(), tup._1());
		}
	});
	return res;
    }

    public static DataFrame toDF(SQLContext ctx, JavaRDD<Row> rdd, String col1, String col2) {
	StructType st =
	  new StructType().add(col1, DataTypes.LongType)
	                  .add(col2, DataTypes.StringType);

	DataFrame df = ctx.createDataFrame(rdd, st);
	return df;
    }

    public static JavaRDD<Row> fromDF(DataFrame df, String col1, String col2) {
        return df.select(col1, col2).toJavaRDD();
    }

    public static JavaPairRDD<Long, Vector> fromRows(JavaRDD<Row> rows) {
        JavaPairRDD<Long, Vector> res = rows.mapToPair(
	    new PairFunction<Row, Long, Vector>() {
		public Tuple2<Long, Vector> call(Row r) {
		    return new Tuple2<Long, Vector>((Long) r.get(0), (Vector) r.get(1));
		}
	    });
        return res.cache();
    }

    public static LDAModel runLDA(LDA l, JavaPairRDD<Long, Vector> docs) {
	return l.run(docs);
    }

    public static void describeResults(LDAModel lm, CountVectorizerModel cvm, int maxTermsPerTopic) {
	Tuple2<int[], double[]>[] topics = lm.describeTopics(maxTermsPerTopic);
	String[] vocabArray = cvm.vocabulary();
	System.out.println(">>> Vocabulary");
	for(String w : vocabArray)
	    System.out.println("\t " + w);
	for(int i = 0; i < topics.length; i++) {
	    System.out.println(">>> Topic #" + i);
	    Tuple2<int[], double[]> topic = topics[i];
	    int numTerms = topic._1().length;
	    for(int j = 0; j < numTerms; j++) {
		String term = vocabArray[topic._1()[j]];
		double weight = topic._2()[j];
		System.out.println("\t" + term + " -> " + weight);
	    }
	    System.out.println("-----");
	}
    }
}
