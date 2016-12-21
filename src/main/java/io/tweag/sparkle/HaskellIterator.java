package io.tweag.sparkle;

import io.tweag.sparkle.SparkleBase;

/**
 * The elements of this iterator are obtained by calling successively a native
 * function.
 *
 * SparkleBase is extended in order to ensure that the code of the native
 * methods is loaded.
 * */
public class HaskellIterator<T> extends SparkleBase
                                implements java.util.Iterator<T> {

    /// This is a pointer to a function in a StablePtr.
    private final long fun;
    /// A field that the Haskell side sets to true when it reaches the end.
    private boolean end;

    /**
     * Creates the Iterator from a pointer to a function in a StablePtr that
     * produces the elements.
     * */
    public HaskellIterator(final long fun, final boolean end) {
        this.fun = fun;
        this.end = end;
    }

    @Override
    public boolean hasNext() {
        return !end;
    }

    @Override
    public T next() {
        return iteratorNext(fun);
    }

    @Override
    public void remove() {
        throw new UnsupportedOperationException();
    }

    @Override
    protected void finalize() {
        // Don't free the pointer if we reached the end.
        // In that case the pointer is already released.
        if (!end) freeStablePtr(fun);
    }

    /// Calls the function pointer passing *this* as argument.
    private native T iteratorNext(long fun);
    private static native void freeStablePtr(long fun);
}

