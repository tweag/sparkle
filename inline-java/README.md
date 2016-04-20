# inline-java: Call any JVM function from Haskell

The Haskell standard includes a native foreign function interface
(FFI). It can be a pain to use and in any case only C support is
implemented in GHC. `inline-java` lets you call any JVM function
directly, from Haskell, without the need to write your own foreign
import declarations using the FFI. In the style of `inline-c` for C and
`inline-r` for calling R, `inline-java` lets you name any function to
call inline in your code.

**This is an early tech preview, not production ready.**

**Quasiquotation to make inline calls in Java syntax not yet
  implemented. But calls in Haskell syntax supported.**

# Example

Graphical Hello World using Java Swing:

```Haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

import Data.Text (Text)
import Language.Java

newtype JOptionPane = JOptionPane (J ('Class "javax.swing.JOptionPane"))
instance Coercible JOptionPane ('Class "javax.swing.JOptionPane")

main :: IO ()
main = withJVM [] $ do
    message <- reflect ("Hello World!" :: Text)
    callStatic
      (classOf (undefined :: JOptionPane))
      "showMessageDialog"
      [JObject nullComponent, JObject (upcast message)]
  where
    nullComponent :: J ('Class "java.awt.Component")
    nullComponent = jnull
```
## License

Copyright (c) 2015-2016 EURL Tweag.

All rights reserved.

Sparkle is free software, and may be redistributed under the terms
specified in the [LICENSE](LICENSE) file.

## About

![Tweag I/O](http://i.imgur.com/0HK8X4y.png)

Sparkle is maintained by [Tweag I/O](http://tweag.io/).

Have questions? Need help? Tweet at
[@tweagio](http://twitter.com/tweagio).
