-- | = Inline Java quasiquotation
--
-- See the
-- <https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html#template-haskell-quasi-quotation GHC manual>
-- for an introduction to quasiquotation. The quasiquoter exported in this
-- module allows embedding arbitrary Java expressions and blocks of statements
-- inside Haskell code. You can call any Java method and define arbitrary inline
-- code using Java syntax. No FFI required.
--
-- Here is the same example as in "Language.Java", but with inline Java calls:
--
-- @
-- {&#45;\# LANGUAGE DataKinds \#&#45;}
-- {&#45;\# LANGUAGE QuasiQuotes \#&#45;}
-- module Object where
--
-- import Language.Java as J
-- import Language.Java.Inline
--
-- newtype Object = Object ('J' (''Class' "java.lang.Object"))
-- instance 'Coercible' Object
--
-- clone :: Object -> IO Object
-- clone obj = [java| $obj.clone() |]
--
-- equals :: Object -> Object -> IO Bool
-- equals obj1 obj2 = [java| $obj1.equals($obj2) |]
--
-- ...
-- @

{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}

module Language.Java.Inline
  ( java
  ) where

import Control.Monad (forM_, unless)
import Control.Monad.Fix (mfix)
import Control.Monad.Loops (unfoldM)
import qualified Data.ByteString.Char8 as BS
import Data.Generics (everything, mkQ)
import Data.List (intercalate, isPrefixOf, isSuffixOf)
import Data.Maybe (fromJust)
import Data.Singletons (SomeSing(..))
import Data.String (fromString)
import Data.Traversable (forM)
import Foreign.JNI (defineClass)
import qualified Foreign.JNI.String as JNI
import GHC.Exts (Any)
import qualified GHC.HeapView as HeapView
import GHC.StaticPtr
  ( StaticPtr
  , deRefStaticPtr
  , staticPtrKeys
  , unsafeLookupStaticPtr
  )
import Language.Java
import qualified Language.Java.Parser as Java
import qualified Language.Java.Pretty as Java
import qualified Language.Java.Syntax as Java
import Language.Haskell.TH.Quote
import qualified Language.Haskell.TH as TH
import qualified Language.Haskell.TH.Ppr as TH
import qualified Language.Haskell.TH.Syntax as TH
import Language.Haskell.TH (Q)
import System.FilePath ((</>), (<.>))
import System.IO.Temp (withSystemTempDirectory)
import System.IO.Unsafe (unsafePerformIO)
import System.Process (callProcess)

-- Implementation strategy
--
-- We know we'll need to declare a new wrapper (a Java static method), but we
-- don't know the types of the arguments nor the return type. So we first name
-- this method and generate a Haskell call to it at the quasiquotation site.
-- Then, we register a module finalizer that captures the local scope. At the
-- end of the module, when all type checking is done, our finalizer will be run.
-- By this point the types of all the variables in the local scope that was
-- captured are fully determined. So we can analyze these types to determine
-- what the signature of the wrapper should be, in order to declare it.
--
-- The last step is to ask the Java toolchain to produce .class bytecode from
-- our declarations. We embed this bytecode in the binary, adding a reference to
-- it in the static pointer table (SPT). That way at runtime we can enumerate
-- the bytecode blobs registered in the SPT, and load them into the JVM one by
-- one.

-- | Java code quasiquoter. Example:
--
-- @
-- imports "javax.swing.JOptionPane"
--
-- hello :: IO ()
-- hello = do
--     message <- reflect ("Hello World!" :: Text)
--     [java| JOptionPane.showMessageDialog(null, $message) |]
-- @
--
-- A quasiquote is a snippet of Java code. The code is assumed to be a block
-- (sequence of statements) if the first non whitespace character is a @{@
-- (curly brace) character. Otherwise it's parsed as an expression. Variables
-- with an initial @$@ (dollar) sign are allowed. They have a special meaning:
-- they stand for antiqotation variables (think of them as format specifiers in
-- printf format string). An antiquotation variable @$foo@ is well-scoped if
-- there exists a variable with the name @foo@ in the Haskell context of the
-- quasiquote, whose type is 'Coercible' to a Java primitive or reference type.
java :: QuasiQuoter
java = QuasiQuoter
    { quoteExp = \txt -> blockOrExpQQ txt
    , quotePat  = error "Language.Java.Inline: quotePat"
    , quoteType = error "Language.Java.Inline: quoteType"
    , quoteDec  = error "Language.Java.Inline: quoteDec"
    }

antis :: Java.Block -> [String]
antis = everything (++) (mkQ [] (\case Java.Name [Java.Ident ('$':av)] -> [av]; _ -> []))

toJavaType :: Sing (a :: JType) -> Java.Type
toJavaType ty = case Java.parser Java.ttype (pretty ty) of
    Left err -> error $ "toJavaType: " ++ show err
    Right x -> x
  where
    pretty :: Sing (a :: JType) -> String
    pretty (SClass sym) = JNI.toChars sym
    pretty (SIface sym) = JNI.toChars sym
    pretty (SPrim sym) = JNI.toChars sym
    pretty (SArray ty1) = pretty ty1 ++ "[]"
    pretty (SGeneric _ty1 _tys) = error "toJavaType(Generic): Unimplemented."
    pretty SVoid = "void"

abstract
  :: Java.Ident
  -> Maybe Java.Type
  -> [(Java.Ident, Java.Type)]
  -> Java.Block
  -> Java.MemberDecl
abstract mname retty vtys block =
    Java.MethodDecl [Java.Public, Java.Static] [] retty mname params [] body
  where
    body = Java.MethodBody (Just block)
    params = [ Java.FormalParam [] ty False (Java.VarId v) | (v, ty) <- vtys ]

-- | Decode a TH 'Type' into a 'JType'. So named because it's morally the
-- inverse of 'Language.Haskell.TH.Syntax.lift'.
unliftJType :: TH.Type -> Q (SomeSing JType)
unliftJType (TH.AppT (TH.PromotedT nm) (TH.LitT (TH.StrTyLit sym)))
  | nm == 'Class = return $ SomeSing $ SClass (fromString sym)
  | nm == 'Iface = return $ SomeSing $ SIface (fromString sym)
  | nm == 'Prim = return $ SomeSing $ SPrim (fromString sym)
unliftJType (TH.AppT (TH.PromotedT nm) ty)
  | nm == 'Array = unliftJType ty >>= \case SomeSing jty -> return $ SomeSing (SArray jty)
unliftJType (TH.AppT (TH.AppT (TH.PromotedT _nm) _ty) _tys) =
    error "unliftJType (Generic): Unimplemented."
unliftJType (TH.AppT (TH.ConT nm) lit@(TH.LitT (TH.StrTyLit _))) =
    unliftJType $ TH.AppT (TH.PromotedT nm) lit
unliftJType (TH.PromotedT nm)
  | nm == 'Void = return $ SomeSing SVoid
unliftJType ty = fail $ "unliftJType: cannot unlift " ++ show (TH.ppr ty)

getValueName :: String -> Q TH.Name
getValueName v =
    TH.lookupValueName v >>= \case
      Nothing -> fail $ "Identifier not in scope: " ++ v
      Just name -> return name

makeCompilationUnit
  :: Java.Name
  -> [Java.ImportDecl]
  -> Java.ClassDecl
  -> Java.CompilationUnit
makeCompilationUnit pkgname imports cls =
    Java.CompilationUnit (Just (Java.PackageDecl pkgname)) imports [Java.ClassTypeDecl cls]

makeClass :: Java.Ident -> [Java.MemberDecl] -> Java.ClassDecl
makeClass cname methods =
  Java.ClassDecl
    []
    cname
    []
    Nothing
    []
    (Java.ClassBody
       (map Java.MemberDecl methods))

emit :: FilePath -> Java.CompilationUnit -> IO ()
emit file cdecl = writeFile file (Java.prettyPrint cdecl)

-- | Private newtype to key the TH state.
data FinalizerState = FinalizerState
  { finalizerCount :: Int
  , wrappers :: [Java.MemberDecl]
  }

initialFinalizerState :: FinalizerState
initialFinalizerState = FinalizerState 0 []

getFinalizerState :: Q FinalizerState
getFinalizerState = TH.getQ >>= \case
    Nothing -> do
      TH.putQ initialFinalizerState
      return initialFinalizerState
    Just st -> return st

setFinalizerState :: FinalizerState -> Q ()
setFinalizerState = TH.putQ

incrementFinalizerCount :: Q ()
incrementFinalizerCount =
    getFinalizerState >>= \FinalizerState{..} ->
    setFinalizerState FinalizerState{finalizerCount = finalizerCount + 1, ..}

decrementFinalizerCount :: Q ()
decrementFinalizerCount =
    getFinalizerState >>= \FinalizerState{..} ->
    setFinalizerState FinalizerState{finalizerCount = max 0 (finalizerCount - 1), ..}

isLastFinalizer :: Q Bool
isLastFinalizer = getFinalizerState >>= \FinalizerState{..} -> return $ finalizerCount == 0

pushWrapper :: Java.MemberDecl -> Q ()
pushWrapper w =
    getFinalizerState >>= \FinalizerState{..} ->
    setFinalizerState FinalizerState{wrappers = w:wrappers, ..}

pushWrapperGen :: Q Java.MemberDecl -> Q ()
pushWrapperGen gen = do
    incrementFinalizerCount
    TH.addModFinalizer $ do
      decrementFinalizerCount
      pushWrapper =<< gen
      isLastFinalizer >>= \case
        True -> do
          FinalizerState{wrappers} <- getFinalizerState
          thismod <- TH.thisModule
          unless (null wrappers) $ do
            embedAsBytecode "io/tweag/inlinejava" (mangle thismod) $
              makeCompilationUnit pkgname [] $
                makeClass (Java.Ident (mangle thismod)) wrappers
        False -> return ()
  where
    pkgname = Java.Name $ map Java.Ident ["io", "tweag", "inlinejava"]

-- | A wrapper for class bytecode.
data DotClass = DotClass
  { className :: JNI.String
  , classBytecode :: BS.ByteString
  }

embedAsBytecode :: String -> String -> Java.CompilationUnit -> Q ()
embedAsBytecode pkg name unit = do
  bcode <- TH.runIO $ do
    withSystemTempDirectory "inlinejava" $ \dir -> do
      let src = dir </> name <.> "java"
      emit src unit
      putStrLn (Java.prettyPrint unit)
      callProcess "javac" [src]
      BS.readFile (dir </> name <.> "class")
  f <- TH.newName "inlinejava__bytecode"
  TH.addTopDecls =<<
    sequence
      [ TH.sigD f [t| StaticPtr DotClass |]
      , TH.valD
          (TH.varP f)
          (TH.normalB
             [| static
                  (DotClass (fromString $(TH.lift (pkg ++ "/" ++ name)))
                  (BS.pack $(TH.lift (BS.unpack bcode)))) |])
          []
      ]

newtype ClassLoader = ClassLoader (J ('Class "java.lang.ClassLoader"))
instance Coercible ClassLoader ('Class "java.lang.ClassLoader")

-- | Idempotent action that loads all wrappers in every module of the current
-- program into the JVM.
loadJavaWrappers :: IO ()
loadJavaWrappers = doit `seq` return ()
  where
    {-# NOINLINE doit #-}
    doit = unsafePerformIO $ do
      keys <- staticPtrKeys
      loader :: ClassLoader <-
        callStatic (classOf (undefined :: ClassLoader)) "getSystemClassLoader" []
      forM_ keys $ \key -> do
        sptr :: StaticPtr Any <- fromJust <$> unsafeLookupStaticPtr key
        let !x = deRefStaticPtr sptr
        HeapView.getClosureData x >>= \case
          HeapView.ConsClosure{..}
            | "inline-java" `isPrefixOf` pkg
            , intercalate "." [modl, name] == show 'DotClass -> do
                clsPtr <- fromJust <$> unsafeLookupStaticPtr key
                let DotClass clsname bcode = deRefStaticPtr clsPtr
                _ <- defineClass clsname loader bcode
                return ()
          _ -> return ()

mangle :: TH.Module -> String
mangle (TH.Module (TH.PkgName pkgname) (TH.ModName mname)) =
    "Inline__" ++ pkgname ++ "_" ++ map (\case '.' -> '_'; x -> x) mname

data Some = forall ty. Some (IO (J ty))

blockOrExpQQ :: String -> Q TH.Exp
blockOrExpQQ txt@(words -> toks) -- ignore whitespace
  | ["{"] `isPrefixOf` toks
  , ["}"] `isSuffixOf` toks = blockQQ txt
  | otherwise = expQQ txt

expQQ :: String -> Q TH.Exp
expQQ input = blockQQ $ "{ return " ++ input ++ "; }"

blockQQ :: String -> Q TH.Exp
blockQQ input = case Java.parser Java.block input of
    Left err -> fail $ show err
    Right block -> do
      mname <- TH.newName "function"
      pushWrapperGen $ do
        vtys <- forM (antis block) $ \v -> do
          name <- getValueName v
          info <- TH.reify name
          TH.runIO $ print info
          case info of
#if MIN_VERSION_template_haskell(2,11,0)
            TH.VarI _ (TH.AppT (TH.ConT nJ) thty) _
#else
            TH.VarI _ (TH.AppT (TH.ConT nJ) thty) _ _
#endif
              | nJ == ''J -> do
              unliftJType thty >>= \case
                SomeSing ty1 -> return $ (Java.Ident ('$':v), toJavaType ty1)
#if MIN_VERSION_template_haskell(2,11,0)
            TH.VarI _ ty _ -> do
#else
            TH.VarI _ ty _ _ -> do
#endif
              targetty <- TH.newName "a"
              instances <- TH.reifyInstances ''Coercible [ty, TH.VarT targetty]
              jty <- case instances of
                [TH.InstanceD _ _ (TH.AppT (TH.AppT _ _) thty) _] -> unliftJType thty >>= \case
                  SomeSing ty1 -> return $ toJavaType ty1
                [] -> fail $ "No Coercible instance for type " ++ show (TH.ppr ty)
                _ ->
                  fail $
                  "Ambiguous argument type " ++
                  show (TH.ppr ty) ++
                  ". Several Coercible instances apply."
              return (Java.Ident ('$':v), jty)
            _ -> fail $ v ++ " not a valid variable name."
        let retty = toJavaType (SClass "java.lang.Object")
        return $ abstract
          (Java.Ident (show mname))
          (Just retty)
          vtys
          block
      -- Return a call to the static method we just generated.
      let args = [ [| coerce $(TH.varE =<< getValueName v) |] | v <- antis block ]
      thismod <- TH.thisModule
      castReturnType
        [| loadJavaWrappers >>
           callStatic
             (sing :: Sing $(TH.litT $ TH.strTyLit ("io.tweag.inlinejava." ++ mangle thismod)))
             (fromString $(TH.stringE (show mname)))
             $(TH.listE args) :: IO (J ('Class "java.lang.Object")) |]
    where
      -- As of GHC 8.0.2, 'addModFinalizer' will only see variables that are
      -- already in scope at the call site, not new variables that are spliced
      -- in. So we can't get at the return type of the call to the wrapper we
      -- just generated. Therefore, we have no choice but to assume all wrappers
      -- always return java.lang.Object. This works, because in Java >= 5 if
      -- what you have is a primitive type but what you're requesting is an
      -- object type, then the value of primitive type gets autoboxed. So now we
      -- have to guess on the Haskell side what autoboxing did. We assume
      -- autoboxing is equivalent to reflecting a value at primitive type.
      --
      -- We have to write part of this programmatically due to a TH limitation,
      -- https://ghc.haskell.org/trac/ghc/ticket/12164. It stands for:
      --
      -- @
      -- [| -- Determine what Java type we'd get if we reflected the result.
      --    -- That's the type we need to reify from.
      --    mfix $ \x -> case Some (reflect x) of
      --      Some (_ :: IO (J ty)) -> do
      --        y <- $funcall
      --        reify (unsafeCast y :: J ty)
      --  |]
      -- @
      castReturnType funcall = do
        ty <- TH.newName "ty"
        [| mfix $ \x ->
             $(TH.caseE
                 [| Some (reflect x) |]
                 [TH.match
                    (TH.conP 'Some [TH.sigP TH.wildP [t| IO (J $(TH.varT ty)) |]])
                    (TH.normalB [| do
                       y <- $funcall
                       reify (unsafeCast y :: J ty) |])
                    []]) |]
