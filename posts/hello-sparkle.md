# Haskell meets large scale distributed analytics

Large scale distributed applications are complex: there are effects at
scale that matter far more than when your application is basked in the
warmth of a single machine. Messages between any two processes may or
may not make it to their final destination. If reading from a memory
bank yields corrupted bytes about once a year, with 10,000 nodes this
is likely to happen within the hour. In a million components system
some hardware somewhere will be in a failed state, continuously. It
takes cunning to maximize throughput when network latencies are vastly
superior to processing units' crunch power. The key idea behind
distributed computing middlewares such as Hadoop is to capture common
application patterns, and solve coping with these effects once and for
all for each such pattern, so that applications writers don't have to
do so themselves from scratch every time. Today we're introducing an
early release of Sparkle. The motto: implement a robust and scalable
distributed computing middleware for Haskell, by reusing Spark.

Why Spark? We could as well have built a complete platform starting
from the likes of Cloud Haskell, which we maintain. And distributed
computing engines is increasingly becoming a crowded space. We started
by asking a simple question: if I'm a data scientist seeking to train
a model with state-of-the-art machine learning techniques, what is my
best option to get the job done? How can I do that without giving up
Haskell's strong static guarantees and concise syntax?

Spark is a popular piece of the puzzle that leverages the huge Hadoop
ecosystem for storage and cluster resource management to make it easy
to write robust and scalable distributed applications as the
composition of basic but familiar combinators to us FP aficionados:
(distributed!) `map`, `filter`, `zip`, `reduce`, `concat` and many of
their friends. These patterns generalize the suprisingly effective
MapReduce framework of old. And on top of those, Sparks builds an
impressively large set of general machine learning techniques as
a library.

Today, Spark is already available to write scalable Scala, Java, R or
Python applications. Haskell is a great language for writing clearly
the kind of intricately complex algorithms common in analytics, **so
we're throwing it into the mix**.

## Spark basics

Let's start with a trivial "Hello World" Spark application in Scala:

```scala
import org.apache.spark.SparkContext
import org.apache.spark.SparkContext._
import org.apache.spark.SparkConf

object SimpleApp {
  def main(args: Array[String]) {
    val conf = new SparkConf().setAppName("Hello World")
    val sc = new SparkContext(conf)
    val numbers = 1 to 1000 toArray
    val rdd = sc.parallelize(numbers)
    val doubled = rdd.map(n => 2 * n)
    doubled.collect().foreach(println)
  }
}
```

Nothing too fancy: assuming we have some large vector *somewhere*,
we'd like to compute a new vector with every element doubled. If the
vector really is very large, Spark could choose to do this piecewise
on multiple nodes in parallel.

Spark will break down this high-level description into a number of
low-level tasks, then schedule these tasks to be executed on whatever
nodes in your cluster are available. If any of those tasks fail (e.g
if a node gets disconnected from the cluster), Spark will
automatically reschedule this task on another node, which means
distributed applications written with Spark are fault-tolerant out of
the box.

Spark goes far beyond your basic `map`, `filter` or `fold`: Spark also
provides modules for large-scale graph processing, stream processing,
machine learning and dataframes, all based on a simple abstraction for
distributed collections called "Resilient Distributed Dataset"
(_RDD_).

How does this look like in Haskell? We'll need a little of bit of
Haskell/Scala bridging code for that. The remainder of this post
introduces *Sparkle*, which includes just that.

Be warned that at this stage the latest release of Sparkle is merely
an early tech preview, not the be-all and end-all solution for writing
Spark applications in Haskell (release early, release often!).

## My first Spark app in Haskell

Here goes:

```haskell
{-# LANGUAGE StaticPointers #-}

module HelloSpark where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Control.Distributed.Spark.Closure
import Control.Distributed.Spark.JNI
import Data.List (isInfixOf)

f1 :: String -> Bool
f1 s = "a" `isInfixOf` s

f2 :: String -> Bool
f2 s = "b" `isInfixOf` s

sparkMain :: JVM -> IO ()
sparkMain jvm = do
    env  <- jniEnv jvm
    conf <- newSparkConf env "Hello sparkle!"
    sc   <- newSparkContext env conf
    rdd  <- textFile env sc "stack.yaml"
    as   <- RDD.filter env (closure $ static f1) rdd
    bs   <- RDD.filter env (closure $ static f2) rdd
    numAs <- RDD.count env as
    numBs <- RDD.count env bs
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."

foreign export ccall sparkMain :: JVM -> IO ()
```

Note that once again, Spark may choose to perform the mapping of `f`
over the dataset on one or more remote nodes in the cluster. But if
`f` is an arbitrary closure, how does this one get shipped around the
cluster? Does Sparkle somehow know how to serialize closures into
a sequence of bytes, hand it to Spark, and tell Spark how to
deserialize this closure on the other end of the wire?

That's where the `-XStaticPointers`
[extension][extension-static-pointers] comes in. If you haven't heard
of this before, you might want to follow the link because what we do
in Sparkle is very similar to what's done at the end of that post, in
the _Static Closures_ section. The gist is that we *don't* know how to
serialize *arbitrary* closures, but we do know, thanks to the
`distributed-closure` package, how to serialize and ship *static
closures*, i.e. closures composed of only top-level bindings and
serializable arguments. In Haskell, we need to ask the compiler to
check that the closure really is static by using the `static` keyword.
Spark in Scala has similar limitations, but the static closure check
is entirely implicit (no keyword required, at the cost of some
significant extra magic in the compiler).

[extension-static-pointers]: https://ocharles.org.uk/blog/guest-posts/2014-12-23-static-pointers.html

To run this example from the repo (requires Stack and Nix):

``` bash
# from a clone of github.com/tweag/sparkle
$ ./build.sh hello
$ ./run.sh hello
```

So operationally, Spark handles the input data, notices that our
application is one big map over the whole input data set, figures out
a smart allocation of available nodes to perform parts of the map,
ships a symbolic representation of the function to map (a "static
pointer") to those nodes as necessary, and combines the results
transparently so that we don't have to.

It's a nice enough toy example, but we'll explore next how to use
Sparkle for a real machine learning use case.

## Online Latent Dirichlet Allocation, in Haskell

We'll try
[this Scala application](https://gist.github.com/feynmanliang/3b6555758a27adcb527d)
in Haskell. The goal: classify Wikipedia articles according to the
overall topic they're likely to be covering (zoology? television?
distributed computing?). The method we'll use for this is called
Latent Dirichlet Allocation (LDA), as described in
[the accompanying blog post](https://databricks.com/blog/2015/09/22/large-scale-topic-modeling-improvements-to-lda-on-spark.html),
but here's a one-sentence summary: given a collection of text
documents, the algorithm tries to infer the different topics discussed
in the said documents. The "online" variation consists in learning an
LDA model incrementally, instead of having to go through the entire
collection of documents before it can give us a model. For the
curious, this variation is described in
[this paper](https://www.cs.princeton.edu/~blei/papers/HoffmanBleiBach2010b.pdf).

```haskell
module SparkLDA where

import Control.Distributed.Spark
import Control.Distributed.Spark.JNI
import Foreign.C.Types

sparkMain :: JVM -> IO ()
sparkMain jvm = do
    env <- jniEnv jvm
    stopwords <- getStopwords
    conf <- newSparkConf env "Spark Online Latent Dirichlet Allocation in Haskell!"
    sc   <- newSparkContext env conf
    sqlc <- newSQLContext env sc
    docs <- wholeTextFiles env sc "nyt/"
        >>= justValues env
        >>= zipWithIndex env
    docsRows <- toRows env docs
    docsDF <- toDF env sqlc docsRows "docId" "text"
    tok  <- newTokenizer env "text" "words"
    tokenizedDF <- tokenize env tok docsDF
    swr  <- newStopWordsRemover env stopwords "words" "filtered"
    filteredDF <- removeStopWords env swr tokenizedDF
    cv   <- newCountVectorizer env vocabSize "filtered" "features"
    cvModel <- fitCV env cv filteredDF
    countVectors <- toTokenCounts env cvModel filteredDF "docId" "features"
    lda  <- newLDA env miniBatchFraction numTopics maxIterations
    ldamodel  <- runLDA env lda countVectors
    describeResults env ldamodel cvModel maxTermsPerTopic

    where numTopics         = 10
          miniBatchFraction = 1
          vocabSize         = 600
          maxTermsPerTopic  = 10
          maxIterations     = 50

getStopwords :: IO [String]
getStopwords = fmap lines (readFile "stopwords.txt")

foreign export ccall sparkMain :: JVM -> IO ()
```

Running the above code on [a dataset consisting of articles from the New York Times](https://github.com/cjrd/TMA/tree/master/data/nyt) yields the following
output:

``` bash
# again, from a clone of github.com/tweag/sparkle
$ ./build.sh lda
$ ./run.sh lda
[...]
>>> Topic #0
	atlanta -> 0.05909878836489215
	journal -> 0.03736792191830798
	constitution -> 0.03532890625936911
	moved -> 0.03254662858728971
	service -> 0.02101874084187926
	beach -> 0.01934327641726217
	washington -> 0.015744658734434487
	column -> 0.011533062032191725
	editor -> 0.01027877462336505
	coxnews -> 0.010027441771679654
-----
>>> Topic #1
	rubin -> 0.040416783706726876
	citigroup -> 0.015552806663132827
	enron -> 0.014951083930487013
	first -> 0.014679582063525697
	company -> 0.01296990190006682
	clinton -> 0.012818751484368918
	former -> 0.012721129987043
	policy -> 0.010760148602112128
	business -> 0.010315259378148107
	world -> 0.009556332963292368
-----
>>> Topic #2
	lindh -> 0.10086565288128005
	lawyers -> 0.02809974370319094
	documents -> 0.020200921183457624
	court -> 0.018622599410469412
	taliban -> 0.013285242560186242
	laden -> 0.012629363061761718
	filed -> 0.01222211815409107
	state -> 0.01131786198481124
	tuesday -> 0.010732103491090031
	lawyer -> 0.010634004656851694
-----
>>> Topic #3
	people -> 0.015649313114419607
	first -> 0.014152908458368226
	years -> 0.013390974178862767
	three -> 0.013091944852162668
	american -> 0.009765530939045816
	school -> 0.009240253041043294
	still -> 0.008550106452250891
	business -> 0.00838324576605961
	world -> 0.008210222606562219
	think -> 0.008046033467505353
-----
>>> Topic #4
	state -> 0.013993636365461115
	nuclear -> 0.013454967616138413
	president -> 0.011897250624609038
	government -> 0.011887679419735805
	officials -> 0.011538047974221234
	people -> 0.011470211845182649
	years -> 0.010494996047043077
	paint -> 0.01006800637627191
	federal -> 0.009595218276533429
	administration -> 0.009135440837571944
-----
>>> Topic #5
	democrats -> 0.048477016027800815
	republican -> 0.03372953186909447
	democratic -> 0.030479478447646494
	hockey -> 0.0301577399554842
	party -> 0.030124135903231007
	house -> 0.029891796692788394
	political -> 0.02552022631926487
	republicans -> 0.02349519155470418
	president -> 0.023354691038873904
	washington -> 0.014107623775767722
-----
>>> Topic #6
	times -> 0.023527296114520584
	undated -> 0.015653683177076237
	afghanistan -> 0.01273133526364827
	united -> 0.01242722615113162
	american -> 0.012094814854928493
	world -> 0.011546459807774698
	states -> 0.011226923415847802
	military -> 0.011124624720930143
	service -> 0.009628779935017106
	forces -> 0.009625671286829073
-----
>>> Topic #7
	enron -> 0.05909461214502476
	company -> 0.04107533978443965
	percent -> 0.020163300633107915
	stock -> 0.018054314856199252
	million -> 0.01519085855963182
	energy -> 0.014519899604770029
	business -> 0.013930016959937034
	market -> 0.013468130867634454
	companies -> 0.011941715419144001
	financial -> 0.010156805944316628
-----
>>> Topic #8
	russia -> 0.032427058124270935
	recovery -> 0.021903528020765204
	people -> 0.019697718592083194
	world -> 0.015250431491762355
	years -> 0.01463823505258555
	economic -> 0.014453659833025566
	austin -> 0.011801362135069394
	american -> 0.010444896534955691
	figure -> 0.010375499203498464
	european -> 0.01026866313368857
-----
>>> Topic #9
	engine -> 0.01997218494773725
	power -> 0.019643173099927382
	vehicles -> 0.018688305258300654
	vehicle -> 0.015415769691030158
	economy -> 0.013817767814548005
	energy -> 0.013559557886229668
	standards -> 0.013172974407801281
	model -> 0.013009609194445855
	drive -> 0.012138520071245934
	miles -> 0.011676754602531585
```

## Under the hood: how did we do it?

### Running Haskell code from Java

A Spark application's entry point usually is a Java or Scala program, so one of
the first problems to solve is: how can we just hand everything off to Haskell?

This one was actually reasonably easy to solve. Haskell's GHC compiler
exposes a few functions to manipulate its runtime system from C. On the other
hand, Java lets you call C functions (using JNI, the _Java Native Interface_).
If you put these two together, you can initialize GHC's RTS from Java.

In addition to that, the Haskell FFI lets one export a suitable Haskell
function to C, which we can then call from Java using _JNI_. While we won't
explore all the gory details involved in getting this to work in this post
(most of which reside in passing the right options to build a suitable shared
library with GHC's RTS and a Haskell function in it), we definitely plan on
documenting the entire procedure soon, along with a demo application.

Put simply, what we did on this front lets us call a Haskell function, like:

``` haskell
haskellMain :: IO ()
haskellMain = putStrLn "Hello from Haskell"
```

by exporting it in a shared library and loading the said library from Java,
making sure we initialize GHC's RTS before anything else.

### Calling Java from Haskell

While the previous section was about calling Haskell from Java, this one is
about the opposite direction: calling Java code from Haskell. Indeed, if we
want to write Spark applications in Haskell, we need access to Spark's
classes and methods, in order to initialize a Spark context, create
distributed datasets and perform operations on them.

Fortunately, JNI is not only about calling C from Java. It offers a bridge in
the opposite direction as well, very much like Haskell's FFI. What this means
is that any Java implementation comes with a C library for manipulating the
JVM, through dedicated [types](http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/types.html)
and [functions](http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/functions.html). A couple of `foreign import`s later, we were able to load
Java classes, instantiate them and call their methods, all of this from Haskell
code.

Here's how you would call the `toString()` method on a Java `Object`, using
our preliminary "bindings" to JNI:

``` haskell
toString :: JNIEnv -> JObject -> IO JObject
toString env obj = do
  -- first, we ask the JVM to give us a handle on the Object class
  cls   <- findClass env "java/lang/Object"

  -- we then get our hands on the toString method of that class
  -- with the given signature
  tostr <- findMethod env cls "toString" "()Ljava/lang/String;"

  -- we finally invoke the toString method on the object we are given,
  -- which takes no argument (hence the empty list)
  callObjectMethod env obj tostr []
```

At the moment we do not expose Haskell wrappers for all the types and
functions from the JNI and instead covered only what we needed to write
our initial _sparkle_ demo applications.

Note: "signature" above refers to [the JVM's encoding of type signatures](http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/types.html#wp16432).


## Complete code and examples

All the code for _sparkle_, including the two demos from this blog
post, is available [here](https://github.com/tweag/sparkle). The
`apps/` folder contains the code for the demos while the `sparkle/`
folder contains all the code that makes the demos work.

## Future work

As said at the beginning of this post, this is all in very early stages. There
are several axis of improvements:

- **JNI bindings**: We only expose the bits of JNI that we needed. We might
  want to eventually turn that into proper bindings to the entire JNI API,
  with a nice story for marshalling data back and forth between Haskell and
  Java. The idea there would be that Java values can either be of primitive
  types or objects, so this is all we would ever need to convert to (resp.
  from). We could provide conversion routines for primitive types and `String`
  while keeping Java  objects opaque. This could then be released
  as a (separate) library dedicated to interacting with the JVM.
- **Spark API**: we only cover a ridiculously small fraction of the Spark API.
  Given enough interest we might want to cover more dataset operations as well
  as other Spark modules.
- **Running Haskell functions**: right now, we can barely use Haskell
  functions -- only for `filter` and only with predicates `String -> Bool`.
  This is obviously not enough as we want to support a larger class
  of Haskell computations, for `map`, `filter`, `reduce` and friends. We are
  thinking of two approaches here:

  - Use the marshalling story from the "JNI bindings" bullet above to support
    any function that fits `(FromJObject a, ToJObject b) => a -> b`. This would
    limit users to data types that can be turned into Java objects (Spark
    datasets can only store objects).
  - Encode "arbitrary" Haskell data types as bytestrings, using a format like
    [CBOR](https://github.com/well-typed/binary-serialise-cbor), to support
    functions that fit `(Serialise a, Serialise b) => a -> b`, where
    `Serialise` is the typeclass associated to data types that can be encoded
    from/to CBOR, in the package linked above. This would have the consequence
    of having Spark store datasets of bytestrings that could only be understood
    by our Haskell code out of the box, unless using a CBOR library in other
    languages as well.

## Conclusion

While everything in this post can hardly be considered as more than a proof of
concept, we managed to solve the two main problems in making Haskell a first
class citizen of the Spark ecosystem: we can specify entire Spark applications
directly in Haskell and we can apply Haskell functions over values that live
in the JVM. With some further work, one could turn an "isolated" Haskell
program into a distributed, fault-tolerant application with very little effort.
This isn't the only benefit though: we would gain access to all the Spark
modules out there, and would allow Spark application writers to use the entire
Haskell ecosystem in their applications as well!

This project is, along with other efforts like [HaskellR](http://tweag.github.io/HaskellR/), an attempt at connecting Haskell with other successful
technologies. We can imagine that more companies would be inclined to use
our favorite programming language if it plays well with other technologies
that they use. We certainly hope that a first class support for Haskell in
Spark will help.

