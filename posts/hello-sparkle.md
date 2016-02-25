# Haskell meets large scale distributed analytics

Large scale distributed applications are complex: there are effects at
scale that matter far more than when your application is basked in the
warmth of a single machine. Messages between any two processes may or
may not make it to their final destination. If reading from a memory
bank yields corrupted bytes about once a year, with 10,000 nodes this
is likely to happen within the hour. In a million components system
some hardware somewhere will be in a failed state, continuously. And
it takes cunning to maximize throughput when network latencies are
vastly superior to processing units' crunch power. The key idea behind
distributed computing middlewares such as [Hadoop][hadoop] is to
capture common application patterns, and solve coping with these
effects once and for all for each such pattern, so that applications
writers don't have to do so themselves from scratch every time. Today
we're introducing a tech preview of [sparkle][sparkle]. The motto:
implement a robust and scalable distributed computing middleware for
Haskell, by reusing [Apache Spark][spark] (itself built on top of
parts of Hadoop).

Why Spark? We could as well have built a complete platform starting
from the likes of [Cloud Haskell][cloud-haskell], which we maintain.
And distributed computing engines is increasingly becoming a crowded
space. But we started by asking a simple question: if I'm a data
scientist seeking to train a model with state-of-the-art machine
learning techniques, what is my best option to get the job done? How
can I do that without giving up Haskell's strong static guarantees and
concise syntax?

Spark is a popular piece of the puzzle that leverages the huge
[Hadoop ecosystem][hadoop-ecosystem] for storage and cluster resource
management to make it easy to write robust and scalable distributed
applications as the composition of basic but familiar combinators to
us FP aficionados: (distributed!) `map`, `filter`, `zip`, `reduce`,
`concat` and many of their friends. These patterns generalize the
suprisingly effective MapReduce framework of old. And on top of those,
Sparks builds an impressively large set of general machine learning
techniques as a [library][spark-mllib] (we'll see an example of using
these in this post).

Today, Spark is already available to write scalable Scala, Java, R or
Python applications. Haskell is a great language for writing clearly
the kind of intricately complex algorithms common in analytics, **so
we're throwing Haskell into the mix**. With Haskell, you get the
benefit of a language and ecosystem ruthlessly focused on
refactorability, backed by a state of the art optimizing native code
compiler supporting SIMD intrinsics when you need them.

[cloud-haskell]: http://haskell-distributed.github.io/
[hadoop]: http://hadoop.apache.org/
[hadoop-ecosystem]: https://hadoopecosystemtable.github.io/
[spark]: http://spark.apache.org/
[spark-mllib]: https://spark.apache.org/docs/1.1.0/mllib-guide.html
[sparkle]: https://github.com/tweag/sparkle

## sparkle basics

So what is it like in practice? sparkle's "Hello World" on a hosted
Amazon EMR cluster:

```
# Build it
$ stack build hello
# Package it
$ mvn package -f sparkle -Dsparkle.app=sparkle-example-hello
# Run it
$ spark-submit --master 'spark://IP:PORT' sparkle/target/sparkle-0.1.jar
```

The code looks something like this:

```
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

import Control.Distributed.Spark as RDD
import Data.Text (isInfixOf)

main :: IO ()
main = do
    conf <- newSparkConf "Hello sparkle!"
    sc <- newSparkContext conf
    rdd <- textFile sc "s3://some-bucket/some-file.txt"
    as <- RDD.filter (static (\line -> "a" `isInfixOf` line)) rdd
    numAs <- RDD.count as
    putStrLn $ show numAs ++ " lines with the letter 'a'."
```

Nothing too fancy here: assuming we have some large vector
*somewhere*, we'd like to compute a new vector with every element
doubled. If the vector really is very large, Spark, the underlying
middleware that we're using to write this app, could choose to do this
piecewise on multiple nodes in parallel.

Spark will break down this high-level description into a number of
low-level tasks, then schedule these tasks to be executed on whatever
nodes in your cluster are available. If any of those tasks fail (e.g
if a node gets disconnected from the cluster), *Spark will
automatically reschedule this task on another node*, which means
distributed applications written with Spark are fault-tolerant out of
the box.

Spark goes far beyond your basic `map`, `filter` or `fold`: it also
provides modules for large-scale graph processing, stream processing,
machine learning and dataframes, all based on a simple abstraction for
distributed collections called "Resilient Distributed Dataset"
(_RDD_).

What sparkle does is provide bindings for the API of this middleware,
along with a framework to conveniently write Spark based apps in
Haskell and package them for distribution cluster-wide. There's a lot
more that we can do with this that counting lines - in just a moment
we'll have a look at a full scale machine learning example. But first
let's take a quick peek under the hood.

## Shipping functions across language boundaries and across machines

The core computational content of our app above is captured in the
function `f`. Note that once again, Spark may choose to perform the
filtering by the `f` predicate over the dataset on one or more remote
nodes in the cluster, in parallel. But if `f` is an arbitrary closure,
how does this one get shipped around the cluster? Does sparkle somehow
know how to serialize closures into a sequence of bytes, hand it to
Spark, and tell Spark how to deserialize this closure on the other end
of the wire?

That's where the `-XStaticPointers`
[extension][extension-static-pointers] comes in. If you haven't heard
of this before, you might want to follow the link because what we do
in sparkle is very similar to what's done at the end of that post, in
the _Static Closures_ section. The gist is that we *don't* know how to
serialize *arbitrary* closures, but we do know, thanks to the
`distributed-closure` package, how to serialize and ship so-called
*static closures*, i.e. closures composed of only top-level bindings
and serializable arguments. In Haskell, we need to ask the compiler to
check that the closure really is static by using the `static` keyword.
Spark in Scala has similar limitations, but the static closure check
is entirely implicit (no keyword required, at the cost of some
significant extra magic in the compiler).

[extension-static-pointers]: https://ocharles.org.uk/blog/guest-posts/2014-12-23-static-pointers.html

So operationally, Spark handles the input data, notices that our
application is one big filter over the whole input data set, figures
out a smart allocation of available nodes to perform parts of the map,
ships a symbolic representation of the function to map (a "static
pointer") to those nodes as necessary, and combines the results
transparently so that we don't have to.

It's a nice enough toy example, but we'll explore next how to use
sparkle for a real machine learning use case.

## Online Latent Dirichlet Allocation, from Haskell

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

Here's a snippet of the output from running the above code on
[a dataset consisting of articles from the New York Times][nyt-dataset]:

``` bash
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

.... (a bunch more topics)
```

[nyt]: https://github.com/cjrd/TMA/tree/master/data/nyt

## Complete code and examples

All the code for _sparkle_, including the two demos from this blog
post, is available [here](https://github.com/tweag/sparkle). The
`apps/` folder contains the code for the demos while the `sparkle/`
folder contains all the code that makes the demos work.

## Where to from here?

We set out on a pragmatic mission: marry two different ecosystems that
rarely cross over for a quick, painless but very robust solution to
support common analytics workflows in Haskell. To do so we had to
teach JVM to Haskell, and Haskell to the JVM. It turns out that doing
so was no where near painless (more on that in the next post!), but
quicker than scattering both communities' resources on reimplementing
their own platforms for medium to large scale analytics. Do note that
sparkle is still just a tech preview, but we can already realize these
benefits:

* We get to reuse Spark's Data Sources API to feed data from a wide
  variety of sources (from S3 to HDFS, from CSV to Parquet, ODBC to
  HBase...) into Haskell code.
* Crunching this data on multiple machines at once seamlessly and
  efficiently, with fault-tolerance built-in, using all the power of
  Haskell to readily evolve from prototype to production in record
  time.

Deep within sparkle lies a proto inline-java waiting to break free,
much in the style of [inline-r][inline-r] and [inline-c][inline-c].
That is to say, in pursuit of running Haskell on Spark, we ended up
with most of the basic elements to enable writing mixed syntax source
files including both Java and Haskell for seamless interop. So from
here what we'd like to do is,

* build out a true inline-java to make writing bindings to the rest of
  the Spark API that we haven't yet covered far quicker and more
  flexible,
* incrementally increase our coverage of the Spark API and related
  API's far beyond our current embryonic coverage,
* seamlessly support conversing between Java and Haskell using more
  diverse composite datatypes: we currently know how to efficiently
  swap strings, numeric types and arrays, but a number of composite
  datatypes such as tuples could gainfully be exchanged using
  a standardized data model, such as JSON, or protobufs.

In short, plenty of new directions to contribute towards. :)

[inline-c]: https://www.stackage.org/package/inline-c
[inline-r]: http://tweag.github.io/HaskellR/
