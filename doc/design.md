# Design

The goal of this document is to describe the design for the Haskell interface to Apache Spark.

## Preliminary idea

Let's examine how we can do to get a very simple example to run on a cluster of *Spark*-powered nodes.

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

Now the difficulty resides in what exactly should be exposed, how it could use the serialized closures and how we can send back the result to Java.

#### Making closures "uniform"

We obviously can't afford to try and expose the user-supplied Haskell computations directly, as we don't know their types in advance. A more reasonable thing to do is to pack, along with the function, some wrapper code that'll go fetch the arguments somewhere, decode them and call the function on them, writing the result somewhere before returning the control to Java. This can all be hidden behind the very permissive `IO ()` type, meaning we would send `Closure (IO ())` values over the wire.

The wrapping code would be different depending on the type of the function we are wrapping, but this boilerplate could probably be taken care of by having a typeclass handle this whole aspect once and forall for everyone in our library.

This leaves us with the problem of decoding such closures on the other end (some node in a cluster) and providing them with what they need in order to be run (i.e individual values/rows from the *RDD*). At this point,  all we need to expose to Java is a function that takes such a closure as an argument and does precisely this. Something like:

``` haskell
invoke :: ByteString -> IO ByteString
```

where the `ByteString` argument is a serialized `Closure (IO ())` and the resulting `ByteString` contains the encoded result of applying the user-supplied function to one value or raw from the *RDD*.

#### Providing user-supplied functions with arguments

#### Returning their results to Java
