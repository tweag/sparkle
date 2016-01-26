{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module JNI where

import Data.Map (fromList)
import Foreign.C
import Foreign.Marshal.Array
import Foreign.Ptr
import Foreign.Storable
import Language.C.Inline.Context
import Language.C.Types

-- data JNIEnv_

-- newtype JNIEnv = JNIEnv (Ptr JNIEnv_)

newtype JObject = JObject (Ptr JObject)
  deriving (Eq, Show, Storable)

newtype JClass = JClass (Ptr JClass)
  deriving (Eq, Show, Storable)

newtype JMethodID = JMethodID (Ptr JMethodID)
  deriving (Eq, Show, Storable)

-- newtype JIntArray = JIntArray (Ptr JIntArray)
--  deriving (Eq, Show, Storable)

-- newtype JByteArray = JByteArray (Ptr JByteArray)
--  deriving (Eq, Show, Storable)

-- newtype JString = JString (Ptr JString)
--  deriving (Eq, Show, Storable)
type JString = JObject
type JIntArray = JObject
type JByteArray = JObject

data JValue
  = JObj JObject
  | JInt CInt
  | JByte CChar
  -- | ...

type JValuePtr = Ptr JValue
instance Storable JValue where
  sizeOf _ = 8
  alignment _ = 8

  poke p (JObj o)  = poke (castPtr p) o
  poke p (JInt i)  = poke (castPtr p) i
  poke p (JByte b) = poke (castPtr p) b

  peek _ = error "Storable JValue: undefined peek"

foreign import ccall unsafe "findClass" findClass' :: CString -> IO JClass 
foreign import ccall unsafe "newObject" newObject' :: JClass -> CString -> JValuePtr -> IO JObject
foreign import ccall unsafe "findMethod" findMethod' :: JClass -> CString -> CString -> IO JMethodID
foreign import ccall unsafe "findStaticMethod" findStaticMethod' :: JClass -> CString -> CString -> IO JMethodID
foreign import ccall unsafe "callObjectMethod" callObjectMethod' :: JObject -> JMethodID -> JValuePtr -> IO JObject
foreign import ccall unsafe "callStaticObjectMethod" callStaticObjectMethod' :: JClass -> JMethodID -> JValuePtr -> IO JObject
foreign import ccall unsafe "newIntArray" newIntArray' :: CSize -> Ptr CInt -> IO JIntArray
foreign import ccall unsafe "newByteArray" newByteArray' :: CSize -> Ptr CChar -> IO JByteArray
foreign import ccall unsafe "newString" newString' :: Ptr CChar -> IO JString

findClass :: String -> IO JClass
findClass s = withCString s findClass'

newObject :: JClass -> String -> [JValue] -> IO JObject
newObject cls sig args =
  withCString sig $ \csig ->
  withArray args $ \cargs ->
  newObject' cls csig cargs

findMethod :: JClass -> String -> String -> IO JMethodID
findMethod cls methodname sig =
  withCString methodname $ \cmethodname ->
  withCString sig $ \csig ->
  findMethod' cls cmethodname csig

findStaticMethod :: JClass -> String -> String -> IO JMethodID
findStaticMethod cls methodname sig =
  withCString methodname $ \cmethodname ->
  withCString sig $ \csig ->
  findStaticMethod' cls cmethodname csig

callObjectMethod :: JObject -> JMethodID -> [JValue] -> IO JObject
callObjectMethod obj method args =
  withArray args $ \cargs ->
  callObjectMethod' obj method cargs

callStaticObjectMethod :: JClass -> JMethodID -> [JValue] -> IO JObject
callStaticObjectMethod cls method args =
  withArray args $ \cargs ->
  callStaticObjectMethod' cls method cargs

newIntArray :: CSize -> [CInt] -> IO JIntArray
newIntArray sz xs =
  withArray xs $ \cxs ->
  newIntArray' sz cxs

newByteArray :: CSize -> [CChar] -> IO JByteArray
newByteArray sz xs =
  withArray xs $ \cxs ->
  newByteArray' sz cxs

newString :: String -> IO JString
newString s = withCString s newString'

jniCtx :: Context
jniCtx = mempty { ctxTypesTable = fromList tytab }
  where
    tytab =
      [ (TypeName "jobject", [t| JObject |]) ]
