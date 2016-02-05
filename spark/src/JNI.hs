{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module JNI where

import Data.Map (fromList)
import Foreign.C
import Foreign.Marshal.Array
import Foreign.Ptr
import Foreign.Storable
import Language.C.Inline.Context
import Language.C.Types

newtype JObject = JObject (Ptr JObject)
  deriving (Eq, Show, Storable)

newtype JClass = JClass (Ptr JClass)
  deriving (Eq, Show, Storable)

newtype JMethodID = JMethodID (Ptr JMethodID)
  deriving (Eq, Show, Storable)

type JString = JObject
type JIntArray = JObject
type JByteArray = JObject
type JDoubleArray = JObject
type JObjectArray = JObject

data JValue
  = JObj JObject
  | JInt CInt
  | JByte CChar
  | JDouble CDouble
  | JBoolean CUChar
  -- | ...

type JValuePtr = Ptr JValue

instance Storable JValue where
  sizeOf _ = 8
  alignment _ = 8

  poke p (JObj o)     = poke (castPtr p) o
  poke p (JInt i)     = poke (castPtr p) i
  poke p (JByte b)    = poke (castPtr p) b
  poke p (JDouble d)  = poke (castPtr p) d
  poke p (JBoolean b) = poke (castPtr p) b

  peek _ = error "Storable JValue: undefined peek"

foreign import ccall unsafe "findClass" findClass' :: CString -> IO JClass 
foreign import ccall unsafe "newObject" newObject' :: JClass -> CString -> JValuePtr -> IO JObject
foreign import ccall unsafe "findMethod" findMethod' :: JClass -> CString -> CString -> IO JMethodID
foreign import ccall unsafe "findStaticMethod" findStaticMethod' :: JClass -> CString -> CString -> IO JMethodID
foreign import ccall unsafe "callObjectMethod" callObjectMethod' :: JObject -> JMethodID -> JValuePtr -> IO JObject
foreign import ccall unsafe "callStaticObjectMethod" callStaticObjectMethod' :: JClass -> JMethodID -> JValuePtr -> IO JObject
foreign import ccall unsafe "callStaticVoidMethod" callStaticVoidMethod' :: JClass -> JMethodID -> JValuePtr -> IO ()
foreign import ccall unsafe "callVoidMethod" callVoidMethod' :: JObject -> JMethodID -> JValuePtr -> IO ()
foreign import ccall unsafe "newIntArray" newIntArray' :: CSize -> Ptr CInt -> IO JIntArray
foreign import ccall unsafe "newDoubleArray" newDoubleArray' :: CSize -> Ptr CDouble -> IO JDoubleArray
foreign import ccall unsafe "newByteArray" newByteArray' :: CSize -> Ptr CChar -> IO JByteArray
foreign import ccall unsafe "newObjectArray" newObjectArray' :: CSize -> JClass -> Ptr JObject -> IO JObjectArray
foreign import ccall unsafe "newString" newString' :: Ptr CChar -> IO JString
foreign import ccall unsafe "checkForExc" checkForException :: IO ()

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

callVoidMethod :: JObject -> JMethodID -> [JValue] -> IO ()
callVoidMethod obj method args =
  withArray args $ \cargs ->
  callVoidMethod' obj method cargs

callStaticObjectMethod :: JClass -> JMethodID -> [JValue] -> IO JObject
callStaticObjectMethod cls method args =
  withArray args $ \cargs ->
  callStaticObjectMethod' cls method cargs

callStaticVoidMethod :: JClass -> JMethodID -> [JValue] -> IO ()
callStaticVoidMethod cls method args =
  withArray args $ \cargs ->
  callStaticVoidMethod' cls method cargs

newIntArray :: CSize -> [CInt] -> IO JIntArray
newIntArray sz xs =
  withArray xs $ \cxs ->
  newIntArray' sz cxs

newDoubleArray :: CSize -> [CDouble] -> IO JDoubleArray
newDoubleArray sz xs =
  withArray xs $ \cxs ->
  newDoubleArray' sz cxs

newByteArray :: CSize -> [CChar] -> IO JByteArray
newByteArray sz xs =
  withArray xs $ \cxs ->
  newByteArray' sz cxs

newObjectArray :: CSize -> JClass -> [JObject] -> IO JObjectArray
newObjectArray sz cls xs =
  withArray xs $ \cxs ->
  newObjectArray' sz cls cxs

newString :: String -> IO JString
newString s = withCString s newString'

jniCtx :: Context
jniCtx = mempty { ctxTypesTable = fromList tytab }
  where
    tytab =
      [ (TypeName "jobject", [t| JObject |]) ]
