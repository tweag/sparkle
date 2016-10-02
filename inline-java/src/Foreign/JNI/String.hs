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
  , unsafeFromByteString
  , toByteString
  , withString
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BS
import Data.ByteString (ByteString)
import Data.String (IsString(..))
import Foreign.C.String (CString)
import qualified GHC.Foreign as GHC
import qualified GHC.IO.Encoding as GHC
import System.IO.Unsafe (unsafeDupablePerformIO)
import qualified Prelude
import Prelude hiding (String)

newtype String = String ByteString
  deriving (Eq)

instance Show String where
  show str = show (toChars str)

instance IsString String where
  fromString str = fromChars str

fromChars :: Prelude.String -> String
{-# INLINE [0] fromChars #-}
fromChars str = unsafeDupablePerformIO $ do
    String <$> (BS.unsafePackCString =<< GHC.newCString GHC.utf8 str)

toChars :: String -> Prelude.String
toChars (String bs) = unsafeDupablePerformIO $ BS.unsafeUseAsCString bs $ GHC.peekCString GHC.utf8

withString :: String -> (CString -> IO a) -> IO a
withString (String bs) f = BS.unsafeUseAsCString bs f

toByteString :: String -> ByteString
toByteString (String bs) = bs

-- | O(1) if the input is null-terminated. Otherwise the input is copied into
-- a null-terminated buffer first.
fromByteString :: ByteString -> String
fromByteString bs
  | BS.last bs == 0 = String bs
  | otherwise = String (bs `BS.snoc` 0)

-- | Same as 'fromByteString', but doesn't check whether the input is
-- null-terminated or not.
unsafeFromByteString :: ByteString -> String
unsafeFromByteString = String
