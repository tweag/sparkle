-- | JNI strings. Like C strings and unlike 'Data.ByteString.ByteString', these
-- are null-terminated. Unlike C strings, each character is (multi-byte) encoded
-- as UTF-8. Unlike UTF-8, embedded NULL characters are encoded as two bytes and
-- the four-byte UTF-8 format for characters is not recognized. A custom
-- encoding is used instead. See
-- <http://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/types.html#modified_utf_8_strings>
-- for more details.
--
-- /NOTE:/ the current implementation does not support embedded NULL's and
-- four-byte characters.

{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE MagicHash #-}

module Foreign.JNI.String
  ( String
  , toChars
  , fromChars
  , fromByteString
  , toByteString
  , withString
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BS
import Data.ByteString (ByteString)
import Data.String (IsString(..))
import Foreign.C.Types (CChar)
import Foreign.ForeignPtr
  ( ForeignPtr
  , newForeignPtr
  , newForeignPtr_
  , withForeignPtr
  )
import Foreign.Marshal.Alloc (finalizerFree)
import qualified GHC.Foreign as GHC
import qualified GHC.IO.Encoding as GHC
import GHC.Ptr (Ptr(..))
import System.IO.Unsafe (unsafeDupablePerformIO)
import qualified Prelude
import Prelude hiding (String)

newtype String = String (ForeignPtr CChar)

foreign import ccall unsafe "string.h strcmp" strcmp :: Ptr CChar -> Ptr CChar -> Int

instance Eq String where
  String fptr1 == String fptr2 =
    unsafeDupablePerformIO $
    withForeignPtr fptr1 $ \x ->
    withForeignPtr fptr2 $ \y ->
    return $ strcmp x y == 0

instance Show String where
  show str = show (toChars str)

instance IsString String where
  fromString str = fromChars str

fromChars :: Prelude.String -> String
{-# INLINE [0] fromChars #-}
fromChars str = unsafeDupablePerformIO $ do
    cstr <- GHC.newCString GHC.utf8 str
    String <$> newForeignPtr finalizerFree cstr

toChars :: String -> Prelude.String
toChars (String fptr) =
    unsafeDupablePerformIO $ withForeignPtr fptr $ GHC.peekCString GHC.utf8

withString :: String -> (Ptr CChar -> IO a) -> IO a
withString (String fptr) action = withForeignPtr fptr action

toByteString :: String -> ByteString
toByteString (String fptr) =
    unsafeDupablePerformIO $
      withForeignPtr fptr $
        BS.unsafePackCString

-- | O(1) if the input is null-terminated. Otherwise the input is copied into
-- a null-terminated buffer first.
fromByteString :: ByteString -> String
fromByteString bs
  | BS.last bs == 0 = convert bs
  | otherwise = convert (bs `BS.snoc` 0)
  where
    convert bs1 =
      unsafeDupablePerformIO $
        -- No finalizer, because we're reusing the ByteString's buffer, which
        -- already has one (don't want to double free).
        String <$> BS.unsafeUseAsCString bs1 newForeignPtr_
