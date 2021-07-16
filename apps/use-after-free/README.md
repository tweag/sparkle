This program illustrates the fact that we are not safe from use-after-free
errors when using `sparkle`. If one were to refer to the app `memerr`, one might
conclude that the solution for preventing out-of-memory errors due to too many
references would be simply to deallocate said references as they're not needed.
But as soon as we introduce the idea of manual reference management, we open
ourselves up to the new suite of bugs inherent in manual resource management. In
this case, we illustrate this point by producing a use-after-free error.

When run (this program takes no special arguments), we will get one of two
errors. We'll either get a Java `NullPointerException` (as shown in
`null-pointer.txt`), or a segfault (shown in `sigsegv.txt`). The null pointer
exception would likely indicate that the java program successfully deallocated
the reference to the RDD, causing it to get a null pointer exception the next
time it tried to dereference it. The sefault is possibly the result of the
haskell portion trying to dereference the deallocated memory somehow.
