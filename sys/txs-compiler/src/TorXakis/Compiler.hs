{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections     #-}
{-# LANGUAGE ViewPatterns      #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE ScopedTypeVariables  #-}
module TorXakis.Compiler where

import           Control.Arrow                     (first, second, (|||))
import           Control.Lens                      (over, (^.), (^..))
import           Control.Monad.State               (evalStateT, get)
import           Data.Data.Lens                    (uniplate)
import           Data.Map.Strict                   (Map)
import qualified Data.Map.Strict                   as Map
import           Data.Maybe                        (catMaybes, fromMaybe)
import qualified Data.Set                          as Set
import           Data.Text                         (Text)

import           FuncDef                           (FuncDef (FuncDef))
import           FuncId                            (FuncId (FuncId), name)
import           FuncTable                         (FuncTable,
                                                    Signature (Signature),
                                                    toMap)
import           Id                                (Id (Id))
import           Sigs                              (Sigs, chan, func, pro,
                                                    uniqueCombine)
import qualified Sigs                              (empty)
import           SortId                            (sortIdBool, sortIdInt,
                                                    sortIdRegex, sortIdString)
import           ChanId                 (ChanId)                 
import           StdTDefs                          (stdFuncTable, stdTDefs)
import           TxsDefs                           (TxsDefs, fromList, funcDefs, procDefs,
                                                    union, ProcDef, ProcId)
import qualified TxsDefs                           (empty)
import           ValExpr                           (ValExpr,
                                                    ValExprView (Vfunc, Vite),
                                                    cstrITE, cstrVar, view)
import           VarId                             (VarId)
import           SortId                             (SortId)
import           CstrId (CstrId)

import           TorXakis.Compiler.Data
import           TorXakis.Compiler.Defs.ChanId
import           TorXakis.Compiler.Defs.Sigs
import           TorXakis.Compiler.Defs.TxsDefs
import           TorXakis.Compiler.Error           (Error)
import           TorXakis.Compiler.ValExpr.CstrId
import           TorXakis.Compiler.ValExpr.ExpDecl
import           TorXakis.Compiler.ValExpr.FuncDef
import           TorXakis.Compiler.ValExpr.FuncId
import           TorXakis.Compiler.ValExpr.SortId
import           TorXakis.Compiler.ValExpr.VarId
import           TorXakis.Compiler.MapsTo
import           TorXakis.Compiler.Defs.ProcDef
 
import           TorXakis.Parser
import           TorXakis.Parser.Data

-- | Compile a string into a TorXakis model.
--
compileFile :: String -> IO (Either Error (Id, TxsDefs, Sigs VarId))
compileFile fp = do
    ePd <- parseFile fp
    case ePd of
        Left err -> return . Left $ err
        Right pd -> return $
            evalStateT (runCompiler . compileParsedDefs $ pd) newState

-- | Legacy compile function, used to comply with the old interface. It should
-- be deprecated in favor of @compile@.
compileLegacy :: String -> (Id, TxsDefs, Sigs VarId)
compileLegacy = (throwOnLeft ||| id) . compile
    where throwOnLeft = error . show
          compile :: String -> Either Error (Id, TxsDefs, Sigs VarId)
          compile = undefined

compileParsedDefs :: ParsedDefs -> CompilerM (Id, TxsDefs, Sigs VarId)
compileParsedDefs pd = do
    -- Construct the @SortId@'s lookup table.
    sMap <- compileToSortId (pd ^. adts)
    -- Construct the @CstrId@'s lookup table.
    let pdsMap = Map.fromList [ ("Bool", sortIdBool)
                              , ("Int", sortIdInt)
                              , ("Regex", sortIdRegex)
                              , ("String", sortIdString)
                              ]
        allSortsMap = Map.union pdsMap sMap
        e0 = emptyEnv { sortIdT = allSortsMap}
    -- TODO: I'm dumping the map here till we get rid of all these 'Has'X type classes.
    chs <- Map.fromList <$> chanDeclsToChanIds allSortsMap (pd ^. chdecls)        
    cMap <- compileToCstrId allSortsMap (pd ^. adts)
    let e1 = e0 { cstrIdT = cMap }
        allFuncs = pd ^. funcs ++ pd ^. consts
    stdFuncIds <- getStdFuncIds
    cstrFuncIds <- adtsToFuncIds allSortsMap (pd ^. adts)
    -- Construct the variable declarations table.
    let predefFuncs = funcDefInfoNamesMap $
            (fst <$> stdFuncIds) ++ (fst <$> cstrFuncIds)
    dMap <- generateVarDecls predefFuncs allFuncs
    -- Construct the function declaration to function id table.
    lFIdMap <- funcDeclsToFuncIds allSortsMap allFuncs
    -- Join `lFIdMap` and  `stdFuncIds`.
    let completeFidMap = Map.fromList $ --
            fmap (first FDefLoc) (Map.toList lFIdMap)
            ++ stdFuncIds
            ++ cstrFuncIds
        e2 = e1 { varDeclT = dMap
                , funcIdT = completeFidMap }
    -- Infer the types of all variable declarations.
    vdSortMap <- inferTypes allSortsMap e2 allFuncs
    let e3 = e2 { varSortIdT = vdSortMap }
    -- Construct the variable declarations to @VarId@'s lookup table.
    vMap <- generateVarIds vdSortMap allFuncs
    let e4 = e3 { varIdT = vMap }
    lFDefMap <- funcDeclsToFuncDefs e4 allFuncs
    let e5 = e4 { funcDefT = lFDefMap }
    -- Construct the @ProcId@ to @ProcDef@ map:
    pdefMap <- procDeclsToProcDefMap allSortsMap (pd ^. procs)
    -- Finally construct the TxsDefs.
    let mm = allSortsMap :& pdefMap :& chs :& cMap
    sigs    <- toSigs                mm e5 pd
    txsDefs <- toTxsDefs (func sigs) mm e5 pd
    St i    <- get
    return (Id i, txsDefs, sigs)

-- | Try to apply a handler to the given function definition (which is described by a pair).
--
-- TODO: Return an Either instead of throwing an error.
simplify' :: FuncTable VarId
          -> [Text] -- ^ Only simplify these function calls. Once we do not
                    -- need to be compliant with the old TorXakis compiler we
                    -- can optimize further.
          -> ValExpr VarId -> ValExpr VarId
simplify' ft fns ex@(view -> Vfunc (FuncId n _ aSids rSid) vs) =
    -- TODO: For now make the simplification only if "n" is a predefined
    -- symbol. Once compliance with the current `TorXakis` compiler is not
    -- needed we can remove this constraint and simplify further.
    if n `elem` fns
    then fromMaybe (error "Could not apply handler") $ do
        sh <- Map.lookup n (toMap ft)
        h  <- Map.lookup (Signature aSids rSid) sh
        return $ h (simplify' ft fns <$> vs)
    else ex

simplify' ft fns (view -> Vite ex0 ex1 ex2) = cstrITE
                                             (simplify' ft fns ex0)
                                             (simplify' ft fns ex1)
                                             (simplify' ft fns ex2)
simplify' ft fns x                          = over uniplate (simplify' ft fns) x

simplify :: FuncTable VarId -> [Text] -> (FuncId, FuncDef VarId) -> (FuncId, FuncDef VarId)
-- TODO: return an either instead.
simplify ft fns (fId, FuncDef vs ex) = (fId, FuncDef vs (simplify' ft fns ex))

toTxsDefs :: ( MapsTo Text        SortId mm
             , MapsTo (Loc CstrE) CstrId mm
             , HasFuncIds e
             , HasFuncDefs e
             , MapsTo ProcId ProcDef mm
             , MapsTo Text ChanId mm )
          => FuncTable VarId -> mm -> e -> ParsedDefs -> CompilerM TxsDefs
toTxsDefs ft mm e pd = do
    ads <- adtsToTxsDefs mm (pd ^. adts)
    -- Get the function id's of all the constants.
    cfIds <- traverse (findFuncIdForDeclM e) (pd ^.. consts . traverse . loc')
    let
        -- TODO: we have to remove the constants to comply with what TorXakis generates :/
        funcDefsNoConsts = Map.withoutKeys (getFuncDefT e) (Set.fromList cfIds)
        -- TODO: we have to simplify to comply with what TorXakis generates.
        fn = idefsNames e ++ fmap name cfIds
        funcDefsSimpl = Map.fromList (simplify ft fn <$> Map.toList funcDefsNoConsts)
        fds = TxsDefs.empty {
            funcDefs = funcDefsSimpl            
            }
        pds = TxsDefs.empty {
            procDefs = innerMap mm
            }    
    -- Extract the model definitions
    let chIdsMap :: Map Text ChanId
        chIdsMap = innerMap mm
    mds <- modelDeclsToTxsDefs chIdsMap (pd ^. models)
    return $ ads
        `union` fds
        `union` pds        
        `union` fromList stdTDefs        
        `union` mds

toSigs :: ( MapsTo Text        SortId mm
          , MapsTo (Loc CstrE) CstrId mm
          , HasFuncIds e
          , HasFuncDefs e
          , MapsTo ProcId ProcDef mm
          , MapsTo Text ChanId mm)
       => mm -> e -> ParsedDefs -> CompilerM (Sigs VarId)
toSigs mm e pd = do
    let ts   = sortsToSigs (innerMap mm)
    as  <- adtDeclsToSigs mm   (pd ^. adts)
    fs  <- funDeclsToSigs mm e (pd ^. funcs)
    cs  <- funDeclsToSigs mm e (pd ^. consts)
    let pidMap :: Map ProcId ProcDef
        pidMap = innerMap mm
        ss = Sigs.empty { func = stdFuncTable
                        , chan = Map.elems (innerMap mm :: Map Text ChanId)
                        , pro  = Map.keys pidMap
                        }
    return $ ts `uniqueCombine` as
        `uniqueCombine` fs
        `uniqueCombine` cs
        `uniqueCombine` ss

funcDefInfoNamesMap :: [FuncDefInfo] -> Map Text [FuncDefInfo]
funcDefInfoNamesMap fdis =
    groupByName $ catMaybes $ asPair <$> fdis
    where
      asPair :: FuncDefInfo -> Maybe (Text, FuncDefInfo)
      asPair fdi = (, fdi) <$> fdiName fdi
      groupByName :: [(Text, FuncDefInfo)] -> Map Text [FuncDefInfo]
      groupByName = Map.fromListWith (++) . fmap (second pure)
