{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}        -- For J a
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns #-}

module Foreign.JNI.Types where

import qualified Data.ByteString.Char8 as BS
import Data.ByteString (ByteString)
import Data.Coerce
import Data.Int
import Data.Map (fromList)
import Data.Singletons (Sing, SingI(..), SomeSing(..), KProxy(..))
import Data.Singletons.TypeLits (KnownSymbol, symbolVal)
import Data.Word
import Foreign.C (CChar)
import Foreign.Ptr
import Foreign.Storable (Storable(..))
import GHC.TypeLits (Symbol)
import Language.C.Types (TypeSpecifier(TypeName))
import Language.C.Inline.Context (Context(..))

-- | A JVM instance.
newtype JVM = JVM_ (Ptr JVM)
  deriving (Eq, Show, Storable)

-- | The thread-local JNI context. Do not share this object between threads.
newtype JNIEnv = JNIEnv_ (Ptr JNIEnv)
  deriving (Eq, Show, Storable)

-- | A thread-local reference to a field of an object.
newtype JFieldID = JFieldID_ (Ptr JFieldID)
  deriving (Eq, Show, Storable)

-- | A thread-local reference to a method of an object.
newtype JMethodID = JMethodID_ (Ptr JMethodID)
  deriving (Eq, Show, Storable)

-- | Not part of JNI. Kind of Java object type indexes.
data JType
  = Class Symbol                               -- ^ Class name
  | Iface Symbol                               -- ^ Interface name
  | Prim Symbol                                -- ^ Primitive type
  | Array JType                                -- ^ Array type
  | Generic JType [JType]                      -- ^ Parameterized (generic) type
  | Void                                       -- ^ Void special type

data instance Sing (a :: JType) where
  SClass :: ByteString -> Sing ('Class sym)
  SIface :: ByteString -> Sing ('Iface sym)
  SPrim :: ByteString -> Sing ('Prim sym)
  -- XXX SingI constraint temporary hack because GHC 7.10 has trouble inferring
  -- this constraint in 'signature'.
  SArray :: Sing ty -> Sing ('Array ty)
  SGeneric :: Sing ty -> Sing tys -> Sing ('Generic ty tys)
  SVoid :: Sing 'Void

instance (KnownSymbol sym, SingI sym) => SingI ('Class (sym :: Symbol)) where
  sing = SClass (BS.pack $ symbolVal (undefined :: proxy sym))
instance (KnownSymbol sym, SingI sym) => SingI ('Iface (sym :: Symbol)) where
  sing = SIface (BS.pack $ symbolVal (undefined :: proxy sym))
instance (KnownSymbol sym, SingI sym) => SingI ('Prim (sym :: Symbol)) where
  sing = SPrim (BS.pack $ symbolVal (undefined :: proxy sym))
instance SingI ty => SingI ('Array ty) where
  sing = SArray sing
instance (SingI ty, SingI tys) => SingI ('Generic ty tys) where
  sing = SGeneric sing sing
instance SingI 'Void where
  sing = SVoid

-- | Shorthand for parametized Java types.
type a <> g = 'Generic a g

-- | Type indexed Java Objects.
newtype J (a :: JType) = J (Ptr (J a))
  deriving (Eq, Show, Storable)

type role J representational

-- | Any object can be cast to @Object@.
upcast :: J a -> JObject
upcast = unsafeCast

-- | Unsafe type cast. Should only be used to downcast.
unsafeCast :: J a -> J b
unsafeCast (J x) = J (castPtr x)

-- | Parameterize the type of an object, making its type a /generic type/.
generic :: J a -> J (a <> g)
generic = unsafeCast

-- | Get the base type of a generic type.
unsafeUngeneric :: J (a <> g) -> J a
unsafeUngeneric = unsafeCast

-- | A union type for uniformly passing arguments to methods.
data JValue
  = JBoolean Word8
  | JByte CChar
  | JChar Word16
  | JShort Int8
  | JInt Int32
  | JLong Int64
  | JFloat Float
  | JDouble Double
  | forall a. SingI a => JObject {-# UNPACK#-} !(J a)

instance Show JValue where
  show (JBoolean x) = "JBoolean " ++ show x
  show (JByte x) = "JByte " ++ show x
  show (JChar x) = "JChar " ++ show x
  show (JShort x) = "JShort " ++ show x
  show (JInt x) = "JInt " ++ show x
  show (JLong x) = "JLong " ++ show x
  show (JFloat x) = "JFloat " ++ show x
  show (JDouble x) = "JDouble " ++ show x
  show (JObject x) = "JObject " ++ show (coerce x :: J a)

instance Eq JValue where
  (JBoolean x) == (JBoolean y) = x == y
  (JByte x) == (JByte y) = x == y
  (JChar x) == (JChar y) = x == y
  (JShort x) == (JShort y) = x == y
  (JInt x) == (JInt y) = x == y
  (JLong x) == (JLong y) = x == y
  (JFloat x) == (JFloat y) = x == y
  (JDouble x) == (JDouble y) = x == y
  (JObject (coerce -> J x)) == (JObject (coerce -> J y)) = castPtr x == castPtr y
  _ == _ = False

instance Storable JValue where
  sizeOf _ = 8
  alignment _ = 8

  poke p (JBoolean x) = poke (castPtr p) x
  poke p (JByte x) = poke (castPtr p) x
  poke p (JChar x) = poke (castPtr p) x
  poke p (JShort x) = poke (castPtr p) x
  poke p (JInt x) = poke (castPtr p) x
  poke p (JLong x) = poke (castPtr p) x
  poke p (JFloat x) = poke (castPtr p) x
  poke p (JDouble x) = poke (castPtr p) x
  poke p (JObject x) = poke (castPtr p :: Ptr (J a)) (coerce x)

  peek _ = error "Storable JValue: undefined peek"

jtypeOf :: JValue -> SomeSing ('KProxy :: KProxy JType)
jtypeOf (JBoolean _) = SomeSing (sing :: Sing ('Prim "boolean"))
jtypeOf (JByte _) = SomeSing (sing :: Sing ('Prim "byte"))
jtypeOf (JChar _) = SomeSing (sing :: Sing ('Prim "char"))
jtypeOf (JShort _) = SomeSing (sing :: Sing ('Prim "short"))
jtypeOf (JInt _) = SomeSing (sing :: Sing ('Prim "int"))
jtypeOf (JLong _) = SomeSing (sing :: Sing ('Prim "long"))
jtypeOf (JFloat _) = SomeSing (sing :: Sing ('Prim "float"))
jtypeOf (JDouble _) = SomeSing (sing :: Sing ('Prim "double"))
jtypeOf (JObject (_ :: J ty)) = SomeSing (sing :: Sing ty)

signature :: Sing (ty :: JType) -> ByteString
signature (SClass sym) = "L" `BS.append` BS.map subst sym `BS.append` ";"
  where subst '.' = '/'; subst x = x
signature (SIface sym) = "L" `BS.append` BS.map subst sym `BS.append` ";"
  where subst '.' = '/'; subst x = x
signature (SPrim "boolean") = "Z"
signature (SPrim "byte") = "B"
signature (SPrim "char") = "C"
signature (SPrim "short") = "S"
signature (SPrim "int") = "I"
signature (SPrim "long") = "J"
signature (SPrim "float") = "F"
signature (SPrim "double") = "D"
signature (SPrim sym) = error $ "Unknown primitive: " ++ BS.unpack sym
signature (SArray ty) = "[" `BS.append` signature ty
signature (SGeneric ty _) = signature ty
signature SVoid = "V"

methodSignature
  :: [SomeSing ('KProxy :: KProxy JType)]
  -> Sing (ty :: JType)
  -> ByteString
methodSignature args ret =
    "(" `BS.append`
    BS.concat (map (\(SomeSing s) -> signature s) args) `BS.append`
    ")" `BS.append`
    signature ret

type JObject = J ('Class "java.lang.Object")
type JClass = J ('Class "java.lang.Class")
type JString = J ('Class "java.lang.String")
type JThrowable = J ('Class "java.lang.Throwable")
type JArray a = J ('Array a)
type JObjectArray = JArray ('Class "java.lang.Object")
type JBooleanArray = JArray ('Prim "boolean")
type JByteArray = JArray ('Prim "byte")
type JCharArray = JArray ('Prim "char")
type JShortArray = JArray ('Prim "short")
type JIntArray = JArray ('Prim "int")
type JLongArray = JArray ('Prim "long")
type JFloatArray = JArray ('Prim "float")
type JDoubleArray = JArray ('Prim "double")

jniCtx :: Context
jniCtx = mempty { ctxTypesTable = fromList tytab }
  where
    tytab =
      [ -- Primitive types
        (TypeName "jboolean", [t| Word8 |])
      , (TypeName "jbyte", [t| CChar |])
      , (TypeName "jchar", [t| Word16 |])
      , (TypeName "jshort", [t| Int16 |])
      , (TypeName "jint", [t| Int32 |])
      , (TypeName "jlong", [t| Int64 |])
      , (TypeName "jfloat", [t| Float |])
      , (TypeName "jdouble", [t| Double |])
      -- Reference types
      , (TypeName "jobject", [t| JObject |])
      , (TypeName "jclass", [t| JClass |])
      , (TypeName "jstring", [t| JString |])
      , (TypeName "jarray", [t| JObject |])
      , (TypeName "jobjectArray", [t| JObjectArray |])
      , (TypeName "jbooleanArray", [t| JBooleanArray |])
      , (TypeName "jbyteArray", [t| JByteArray |])
      , (TypeName "jcharArray", [t| JCharArray |])
      , (TypeName "jshortArray", [t| JShortArray |])
      , (TypeName "jintArray", [t| JIntArray |])
      , (TypeName "jlongArray", [t| JLongArray |])
      , (TypeName "jfloatArray", [t| JFloatArray |])
      , (TypeName "jdoubleArray", [t| JDoubleArray |])
      , (TypeName "jthrowable", [t| JThrowable |])
      -- Internal types
      , (TypeName "JavaVM", [t| JVM |])
      , (TypeName "JNIEnv", [t| JNIEnv |])
      , (TypeName "jfieldID", [t| JFieldID |])
      , (TypeName "jmethodID", [t| JMethodID |])
      , (TypeName "jsize", [t| Int32 |])
      , (TypeName "jvalue", [t| JValue |])
      ]
