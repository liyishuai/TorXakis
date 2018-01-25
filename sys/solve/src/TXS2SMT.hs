{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}


-- ----------------------------------------------------------------------------------------- --
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns      #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
module TXS2SMT

-- ----------------------------------------------------------------------------------------- --
--
-- Translate TorXakis definitions, declarations, and assertions into SMT
--
-- ----------------------------------------------------------------------------------------- --
-- export

( initialEnvNames    
, insertSort
, insertCstr
, insertFunc
, basicDefinitionsSMT
, sortdefsToSMT      
, funcdefsToSMT      
, assertionsToSMT    
, declarationsToSMT          
, valexprToSMT       
)

-- ----------------------------------------------------------------------------------------- --
--import

where

import qualified Data.Map      as Map
import           Data.Maybe
import           Data.Monoid
import qualified Data.Set      as Set
import           Data.Text     (Text)
import qualified Data.Text     as T

import           ConstDefs
import           FreeMonoidX
import           FuncDef
import           FuncId
import           Identifier
import           RegexXSD2SMT
import           SMTData
import           SMTString
import           Sort
import           ValExpr
import           Variable
import           VarId

-- ----------------------------------------------------------------------------------------- --
-- initialEnvNames

initialEnvNames :: EnvNames
initialEnvNames  = EnvNames
    Map.empty
    Map.empty
    Map.empty

-- ----------------------------------------------------------------------------------------- --
-- initialEnvNames

toFieldName :: Ref ADTDef -> Ref ConstructorDef -> Int -> Text
toFieldName aRef cRef field  = toCstrName aRef cRef <> "$f" <> (T.pack . show) field

toIsCstrName :: Ref ADTDef -> Ref ConstructorDef -> Text
toIsCstrName aRef cRef  =  "is-" <> toCstrName aRef cRef

toCstrName :: Ref ADTDef -> Ref ConstructorDef -> Text
toCstrName aRef cRef  =  "a" <> (T.pack . show . toInt) aRef <> "$c" <> (T.pack . show . toInt) cRef

toSortName :: Sort -> Text
toSortName SortError   = error "Error is not defined in SMT"
toSortName SortBool    = "Bool"
toSortName SortInt     = "Int"
toSortName SortChar    = error "Char is not yet supported"
toSortName SortString  = "String"
toSortName SortRegex   = error "Regex is not defined in SMT"
toSortname (SortADT r) = toADTName r

toADTName :: Ref ADTDef -> Text
toADTName = "A" <> (T.pack . show . toInt)

toFuncName :: FuncId -> Text
toFuncName funcId  =  T.concat ["f", (T.pack . show) (FuncId.unid funcId), "$", FuncId.name funcId]

insertFunc :: (FuncId, FuncDef VarId) -> EnvNames -> EnvNames
insertFunc (funcId, FuncDef x y) enames
  =  if funcId `Map.member` funcNames enames
       then error $ "TXS TXS2SMT insertMap: Function  (" ++ show funcId ++ ", FuncDef " ++
                    show x ++ " " ++ show y ++  ") already defined\n"
       else enames { funcNames = Map.insert funcId (toFuncName funcId) (funcNames enames) }

-- ----------------------------------------------------------------------------------------- --
-- basic definitions for SMT
-- native Torxakis functions that are not natively supported in SMT
-- ----------------------------------------------------------------------------------------- --
basicDefinitionsSMT :: Text
basicDefinitionsSMT = ""

-- | convert sort definitions to SMT type declarations (as multiple lines of commands)
adtDefsToSMT :: Map.Map (Ref ADTDef) ADTDef -> Text
adtDefsToSMT adtMap
    | null adtMap = ""
    | otherwise   = "(declare-datatypes () (\n"
                       <> foldMap (\s -> "    (" <> toADTName s <> foldMap (cstrToSMT s) (getCstrs s) <> ")\n" )
                                  adtList
                       <> ") )\n"
    where
        -- get the constructors of an ADT
        getCstrs :: SortId -> [(Ref ConstructorDef, CstrDef)]
        getCstrs s = [(cstrId', cstrDef) | (cstrId', cstrDef) <- Map.toList (cstrDefs edefs), cstrsort cstrId' == s]

        -- convert the given constructor to a SMT constructor declaration
        cstrToSMT :: (Ref ConstructorDef, CstrDef) -> Text
        cstrToSMT (cstrId', CstrDef _ fields) = " (" <> justLookupCstr cstrId' enames
                                                     <> cstrFieldsToSMT cstrId' fields 
                                                     <> ")"

        -- convert the given constructor fields to a SMT constructor declaration
        cstrFieldsToSMT :: Ref ConstructorDef -> [FuncId] -> Text
        cstrFieldsToSMT cstrId' fields =
            case fields of
                []  -> ""
                _   -> " (" <> T.intercalate ") (" (map (\(f,p) -> toFieldName cstrId' p <> " " <> justLookupSort (funcsort f) enames)
                                                        (zip fields [0..]) ) <> ")"


-- | Convert function definitions to SMT type declarations (as multiple lines
-- of commands).
funcdefsToSMT :: EnvNames -> Map.Map FuncId (FuncDef VarId) -> Text
funcdefsToSMT enames fdefs =
    toTxs (map toDT (Map.toList fdefs))
  where
    toTxs :: [(Text ,Text)] -> Text
    toTxs [] = ""
    toTxs l = let (lD,lT) = unzip l in
                "(define-funs-rec\n  (\n    " <> T.intercalate "\n    " lD <> "\n  )\n  (\n    " <> T.intercalate "\n    " lT <> "\n  )\n)\n"

    toDT :: (FuncId, FuncDef VarId) -> (Text, Text)
    toDT (funcId, FuncDef vs expr)  = ("(" <> justLookupFunc funcId enames
                                           <> "(" <> T.intercalate " " (map (\v -> "(" <> vname v <> " " <> justLookupSort (varsort v) enames <> ")") vs) <> ") " 
                                           <> justLookupSort (funcsort funcId) enames
                                           <> ")"
                                      , valexprToSMT enames expr
                                      )
-- ----------------------------------------------------------------------------------------- --
-- assertions to SMT
-- ----------------------------------------------------------------------------------------- --
assertionsToSMT :: (Variable v) => EnvNames -> [ValExpr v] -> Text
assertionsToSMT enames assertions =
        T.intercalate "\n" (map assertionToSMT assertions)
    where
        assertionToSMT :: (Variable v) => ValExpr v -> Text
        assertionToSMT expr = "(assert " <> valexprToSMT enames expr <> ")"


integer2smt :: Integer -> Text
integer2smt n | n < 0 = "(- " <> (T.pack . show) (abs n) <> ")"
integer2smt n = (T.pack . show) n
-- ----------------------------------------------------------------------------------------- --
-- constToSMT: translate a const to a SMT constraint
-- ----------------------------------------------------------------------------------------- --
constToSMT :: EnvNames -> Const -> Text
constToSMT _ (Cbool b) = if b
                            then "true"
                            else "false"
constToSMT _ (Cint n) = integer2smt n
constToSMT _ (Cstring s)  =  "\"" <> stringToSMT s <> "\""
constToSMT _ (Cregex r)  =  xsd2smt r
constToSMT enames (Cstr cd [])   =         justLookupCstr cd enames
constToSMT enames (Cstr cd args') = "(" <> justLookupCstr cd enames <> " " <> T.intercalate " " (map (constToSMT enames) args') <> ")"
constToSMT _ x = error ("Illegal input constToSMT - " <> show x)

-- ----------------------------------------------------------------------------------------- --
-- valexprToSMT: translate a ValExpr to a SMT constraint
-- ----------------------------------------------------------------------------------------- --
valexprToSMT :: (Variable v) => EnvNames -> ValExpr v -> Text
valexprToSMT enames (view -> Vfunc funcId [])   =         justLookupFunc funcId enames
valexprToSMT enames (view -> Vfunc funcId args') = "(" <> justLookupFunc funcId enames <> " " <> T.intercalate " " (map (valexprToSMT enames) args') <> ")"

valexprToSMT enames (view -> Vcstr cd [])    =        justLookupCstr cd enames
valexprToSMT enames (view -> Vcstr cd args') = "(" <> justLookupCstr cd enames <> " " <> T.intercalate " " (map (valexprToSMT enames) args') <> ")"

valexprToSMT enames (view -> Viscstr cd arg)    = "(" <> toIsCstrName cd <> " " <> valexprToSMT enames arg <> ")"
valexprToSMT enames (view -> Vaccess cd p arg)  = "(" <> toFieldName cd p <> " " <> valexprToSMT enames arg <> ")"


valexprToSMT enames (view -> Vconst c) = constToSMT enames c

valexprToSMT _ (view -> Vvar varId)  =  vname varId

valexprToSMT enames (view -> Vite c expr1 expr2) = "(ite " <> valexprToSMT enames c <> " "  <> valexprToSMT enames expr1 <> " " <> valexprToSMT enames expr2 <> ")"

valexprToSMT enames (view -> Vsum s) =
    let ol = toOccurListT s in
        case ol of
        {  [o] -> arg2smt o
        ;   _  -> "(+ " <> T.intercalate " " (map arg2smt ol) <> ")"
        }
    where
        arg2smt :: (Variable v) => (ValExpr v, Integer) -> Text
        arg2smt (vexpr, 1)                              = valexprToSMT enames vexpr
        arg2smt (vexpr, -1)                             = "(- " <> valexprToSMT enames vexpr <> ")"
        arg2smt (vexpr, multiplier) |  multiplier /= 0  = "(* " <> integer2smt multiplier <> " " <> valexprToSMT enames vexpr <> ")"
        arg2smt (_, multiplier)                         = error ("valexprToSMT - arg2smt - illegal multiplier " ++ show multiplier)

valexprToSMT enames (view -> Vproduct p) =
    let ol = toOccurListT p in
        case ol of
        {  [o] -> arg2smt o
        ;   _  -> "(* " <> T.intercalate " " (map arg2smt ol) <> ")"
        }
    where
        arg2smt :: (Variable v) => (ValExpr v, Integer) -> Text
        arg2smt (vexpr, 1)                  = valexprToSMT enames vexpr
        arg2smt (vexpr, power) |  power > 0 = "(^ " <> valexprToSMT enames vexpr <> " " <> integer2smt power <> ")"
        arg2smt (_, power)                  = error ("valexprToSMT - arg2smt - illegal power " ++ show power)

valexprToSMT enames (view -> Vdivide t n) = "(div " <> valexprToSMT enames t <> " "  <> valexprToSMT enames n <> ")"
valexprToSMT enames (view -> Vmodulo t n) = "(mod " <> valexprToSMT enames t <> " "  <> valexprToSMT enames n <> ")"
valexprToSMT enames (view -> Vgez v)      = "(<= 0 " <> valexprToSMT enames v <> ")"

valexprToSMT enames (view -> Vequal expr1 expr2)  =
    "(= " <> valexprToSMT enames expr1 <> " " <> valexprToSMT enames expr2 <> ")"

valexprToSMT enames (view -> Vnot expr)  =
    "(not " <> valexprToSMT enames expr <> ")"

valexprToSMT enames (view -> Vand exprs)  =
    "(and " <> T.intercalate " " (map (valexprToSMT enames) (Set.toList exprs)) <> ")"

valexprToSMT enames (view -> Vlength expr)  =
    "(str.len " <> valexprToSMT enames expr <> ")"
valexprToSMT enames (view -> Vat s p)  =
    "(str.at " <> valexprToSMT enames s <> " " <> valexprToSMT enames p <> ")"
valexprToSMT enames (view -> Vconcat vexprs)  =
    "(str.++ " <> T.intercalate " " (map (valexprToSMT enames) vexprs) <> ")"
valexprToSMT enames (view -> Vstrinre s r)  =
    "(str.in.re " <> valexprToSMT enames s <> " " <> valexprToSMT enames r <> ")"
valexprToSMT _ x = error ("Illegal input valexprToSMT - " ++ show x)

-- ----------------------------------------------------------------------------------------- --
declarationsToSMT :: (Variable v) => EnvNames -> [v] -> Text
declarationsToSMT enames vs  =
    T.intercalate "\n" (map declarationToSMT vs)
    where
      declarationToSMT :: (Variable v) => v -> Text
      declarationToSMT v  =  "(declare-fun " <> vname v <> "() " <> justLookupSort (vsort v) enames <> ")"

-- ------------------------------                                                                 

justLookupCstr :: Ref ConstructorDef -> EnvNames -> Text
justLookupCstr cd enames = fromMaybe (error $ "CstrId " ++ show cd ++ " not found in mapping with keys: " ++ show (Map.keys (cstrNames enames)) ++ "\n") (Map.lookup cd (cstrNames enames))

justLookupSort :: SortId -> EnvNames -> Text
justLookupSort sd enames = fromMaybe (error $ "SortId " ++ show sd ++ " not found in mapping with keys: " ++ show (Map.keys (sortNames enames)) ++ "\n") (Map.lookup sd (sortNames enames))

justLookupFunc :: FuncId -> EnvNames -> Text
justLookupFunc fd enames = fromMaybe (error $ "FuncId " ++ show fd ++ " not found in mapping with keys: " ++ show (Map.keys (funcNames enames)) ++ "\n") (Map.lookup fd (funcNames enames))
-- ----------------------------------------------------------------------------------------- --
--
-- ----------------------------------------------------------------------------------------- --
