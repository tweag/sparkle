This program is analagous to the `memerr` example, except it is built using the
safe interface to `sparkle`. As a result, it is not possible (or at least easy)
to write a program that has a memory leak as in the `memerr` example. Rather,
due to the nature of the linear interface, the compiler ensures that all java
references are deleted when they're no longer needed.
