# Design of the *sparkle*, a Haskell interface to Apache Spark

The goal of this document is to describe the design for an Haskell interface to [Apache Spark](http://spark.apache.org/).

## Requirements

This project should eventually provide us with a way to write applications in Haskell that drive an Apache Spark-powered cluster for distributed computing. More precisely, we want:

- to be able to run *Haskell functions* from the nodes of a Spark cluster, which requires a bridge between Java and Haskell, as described later in this document;
- an API to describe the creation, transformation and reduction of *RDD*s from Haskell, that calls out to the Java methods for this while using the aforementionned bridge for evaluating the transformations and reductions;
- a higher-level API that offers the functionality of the various toolboxes (machine learning, graph processing, etc), right in our Haskell code.

## Preliminary idea

Let's examine what we can do to get a very simple example to run on a cluster of *Spark*-powered nodes.

### Running example

The running example will be to ship around (and invoke!) the following function on a Resilient Distributed Dataset (RDD).

``` haskell
double :: Int -> Int
double x = x * 2
```

### Closures

#### Closure creation

Using the `{-# LANGUAGE StaticPointers #-}` extension along with the [distributed-closure](https://github.com/tweag/distributed-closure) package, we can create a `Closure (Int -> Int)` out of our `double` function.

``` haskell
{-# LANGUAGE StaticPointers #-}
import Control.Distributed.Closure (Closure, closure)

doubleClosure :: Closure (Int -> Int)
doubleClosure = closure (static double)
```

#### Serializing a closure

The *distributed-closure* package provides serialization (with [binary](http://hackage.haskell.org/package/binary)) instances for `Closure`s which means we can serialize this function to a lazy `ByteString`:

``` haskell
import Data.Binary (encode)
import Data.ByteString.Lazy (ByteString)

doubleClosureBS :: ByteString
doubleClosureBS = encode doubleClosure
```

#### Deserializing a closure

We also have get deserialization of closures from the aforementionned instance.

``` haskell
import Data.Binary (decode)

doubleClosure' :: Closure (Int -> Int)
doubleClosure' = decode doubleClosureBS
```

#### From closure back to function

When needed, we can easily get back the original function:

``` haskell
import Control.Distributed.Closure (unclosure)

double' :: Int -> Int
double' = unclosure doubleClosure'
```

#### Summary

This means we can serialize functions to be applied to each element of a large dataset (*RDD* in Spark terminology) as simple `ByteString`s, provided that the nodes have a copy of the static pointer table that gets built with the `StaticPointers` extension.

### Getting Java/Scala and Haskell to talk

This closure business is nice but Spark requires us to write computations in Java/Scala, so at some point we need to expose whatever haskell computation the user supplies to the Java/Scala side. The simplest solution for this is to go `Java -> C -> Haskell`. The `Java -> C` bit can be accomplished with the [Java Native Interface (JNI)](https://en.wikipedia.org/wiki/Java_Native_Interface), while we can make Haskell functions available to C using `foreign export` from the Haskell FFI.

Now the difficulty resides in determining exactly what should be exposed, how it could use the serialized closures and how we can send back the result to Java.

#### Making closures "uniform"

We obviously can't afford to try and expose the user-supplied Haskell computations directly, as we don't know their types in advance. A more reasonable thing to do is to pack, along with the function, some wrapper code that'll go fetch the arguments somewhere, decode them and call the function on them, writing the result somewhere before returning the control to Java. This can all be hidden behind the very permissive `ByteString -> ByteString` type, meaning we would send `Closure (ByteString -> ByteString)` values over the wire. The `ByteString` argument could contain one (or more?) arguments to the function we want to apply, while the resulting `ByteString` would be the result of the function encoded with *binary*.

The wrapping code would be different depending on the type of the function we are wrapping, but this boilerplate could probably be taken care of by having a typeclass handle this whole aspect once and forall for everyone in our library.

This leaves us with the problem of decoding such closures on the other end (some node in a cluster) and providing them with what they need in order to be run (i.e individual values/rows from the *RDD*). At this point,  all we need to expose to Java is a function that takes such a closure, arguments and does precisely this. Something like:

``` haskell
invoke :: ByteString    -- ^ serialized closure
       -> ByteString    -- ^ serialized argument(s)
       -> IO ByteString -- ^ serialized result
```

#### Providing user-supplied functions with arguments

From the Java side, we need to pass the serialized closure to `invoke` and feed it with the *RDD*'s elements when actually computing something over the dataset. This means we have to ship `invoke` and everything we might want to use as part of the JAR, along with some "wrapper" Java class that calls out to it through a C stub file and JNI.

#### Returning their results to Java

The result of the call to `invoke` can then be given back to Java. The Java code can put the result back in an *RDD* or aggregate all those results to produce some final value to return to the driver program. It's not clear yet if we can keep "strongly typed" *RDD*s on the Java side or if we have/need to store everything as `ByteString`, relying on some Haskell code for the serialization of everything in the right format for `invoke`, even though we would probably prefer the former despite the fact that the latter would be the sanest approach (and probably the only approach that works for us).

## Milestones

The plan is to progressively solve all the problems involved in getting Haskell functions to be invoked by Spark. This will be accomplished in a few steps.

### 1: Invoking Haskell functions from Java using serialized closures

**Goal**: Have a basic Java class that reads a serialized closure representing a Haskell function from a file, reads its serialized arguments from another, uses `invoke` through a C stub to call the function on the argument(s) and returns the result to Java. This includes figuring out the right compiler spells for Java, C and Haskell. It also involves figuring out the right process for serializing values present in an *RDD* in the right format, *from the Java side*, in order to have the Haskell side be able to decipher it back into Haskell values.

**Timeline**: Estimated between 2 and 7 days, as it might take some time to get the types and representations to align between Haskell, C and Java.

### 2: Shipping Haskell functions with Java/C wrappers

**Goal**: Successfully package up Haskell functions that will end up being applied to individual elements of an *RDD*, along with the object code for `invoke`, the C stub for `invoke` and some Java wrapper code to call out to it. All of that should end up in a .jar file that will be shipped around by Spark so that each node in the cluster ends up with everything it needs to apply Haskell functions to the portions of the *RDD*s they are responsible for. This involves figuring out a bunch of compiler options as well.

**Timeline**: Estimated to take between 2 to 5 days as well. It could take less than 2 days if everything fits together nicely but it would probably be naive to think there's no unforeseen problem in doing this.

### 3: Offering an API to manipulate, transform and reduce *RDD*s that builds on top of *1* and *2*

**Goal**: *1* and *2* are useless if we can't integrate them with the *RDD* framework that Apache Spark offers. If we want to be able to write so-called *driver applications* for Apache Spark from Haskell, we need to be able to create *RDD*s and specify transformations/folds from a Haskell module. The transformations and folding functions themselves would then be sent over the wire to be transmitted to all nodes of a cluster, while the *RDD*-related code would get translated to Java code, in a way or another (?), and the library would take care of (de)serializing everything from Java to C to Haskell and back. Even if the API isn't comprehensive, we want to be able to create basic types of RDDs (e.g from files or Haskell containers) and run distributed computations on them.

**Timeline**: Estimated to take between 1 and 3 weeks. It's not clear yet what the optimal way would be for translating Haskell code that describes the creation, transformation and folding of *RDD*s into Java code. This milestone might get updated in the course of doing *1* and *2*.

### Follow up tasks

If/when we accomplish *1*, *2* and *3*, all the hard problems would be solved and we could then investigate the best approach for exposing the higher-level toolboxes provided by Apache Spark: machine learning, graph processing, distributed SQL, ...
