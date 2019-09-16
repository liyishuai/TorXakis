{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TupleSections         #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE UndecidableInstances  #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  TorXakis.TxsCompiler.ValExpr.SortId
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
--
-- Maintainer  :  damian.nadales@gmail.com (Embedded Systems Innovation by TNO)
-- Stability   :  experimental
-- Portability :  portable
--
-- Compilation functions related to @Sort@ values.
--------------------------------------------------------------------------------
module TorXakis.TxsCompiler.ValExpr.Sort
    ( -- * Sort lookups
--      sortOfVarDecl
--    , sortOfVarDeclM
     checkSorts
    , sortConst
    , sorts
--    , exitSorts
--    , offerSort
--    , exitSort
    -- * Type (Sort) inference.
    , inferVarTypes
    , HasTypedVars
    --, inferTypes
    --, inferExpTypes
    -- * Compilation
    --, compileToSort
    )
where

--import           Control.Arrow            (left, (+++), (|||))
import           Control.Monad            (--foldM,
                                           when)
--import           Control.Monad.Except     (liftEither)
--import           Data.Either              (partitionEithers)
--import           Data.List                (intersect)
--import           Data.Map                 (Map)
--import qualified Data.Map                 as Map
import           Data.Monoid              ((<>))
import           Data.Text                (Text)
import qualified Data.Text                as T
--import           Data.Traversable         (for)
--import           GHC.Exts                 (fromList, toList)
import           Prelude                  hiding (lookup)

--import           TorXakis.FuncSignature   (FuncSignature (args, returnSort))
import           TorXakis.Sort            (Sort (SortBool, SortInt, SortString))

import           TorXakis.TxsCompiler.Data   (CompilerM)
import           TorXakis.TxsCompiler.Error  (Error (Error--, Errors
                                                 ),
                                           ErrorLoc (NoErrorLoc),
                                           ErrorType (TypeMismatch),
--                                           getErrorLoc,
                                           _errorLoc,
                                           _errorMsg, _errorType)
import           TorXakis.TxsCompiler.Maps   (--findFuncDecl
                                           --, findFuncReturnSorts, determineF
                                           --, findSort, getUniqueElement,
                                           (.@!!))
import           TorXakis.TxsCompiler.MapsTo (MapsTo
                                           --, innerMap, lookup,
                                           --values, (<.++>), (<.+>)
                                           )
import           TorXakis.Parser.Data     (Const (AnyConst, BoolConst, IntConst, RegexConst, StringConst),
                                           --ExpChild (ConstLit, Fappl, If, LetExp, VarRef),
                                           --ExpDecl, FuncDecl, FuncDeclE,
                                           --LetVarDecl, 
                                           Loc, OfSort,
                                           --ParLetVarDecl,
                                           VarDecl,
                                           VarDeclE, 
                                           --VarRefE,
                                           --expChild, 
                                           --expLetVarDecls, 
                                           --funcBody,
                                           --funcParams, 
                                           getLoc,
                                           --letVarDeclSortName,
                                           sortRefName,
                                           --varDeclExp,
                                           varDeclSort)

                                           {-
-- | Infer the types in a list of function declarations.
inferTypes :: ( MapsTo Text Sort mm
              , MapsTo (Loc VarDeclE) Sort mm
              , MapsTo (Loc FuncDeclE) FuncSignature mm
              , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
           => mm
           -> [FuncDecl]
           -> CompilerM (Map (Loc VarDeclE) Sort)
inferTypes mm fs = liftEither $ do
    paramsVdSid <- Map.fromList . concat <$> traverse fParamLocSorts fs
    letVdSid    <- foldM (letInferTypes (paramsVdSid <.+> mm)) Map.empty allLetVarDecls
    return $ Map.union letVdSid paramsVdSid
    where
      allLetVarDecls = concatMap letVarDeclsInFunc fs
      fParamLocSorts :: FuncDecl -> Either Error [(Loc VarDeclE, Sort)]
      fParamLocSorts fd = zip (getLoc <$> funcParams fd) <$> fParamSorts
          where
            fParamSorts :: Either Error [Sort]
            fParamSorts = traverse (findSort mm) (varDeclSort <$> funcParams fd)
-}
{-
-- | Infer the types in a list of let-variable-declarations.
letInferTypes :: ( MapsTo Text Sort mm
                 , MapsTo (Loc VarDeclE)  Sort mm
                 , MapsTo (Loc FuncDeclE) FuncSignature mm
                 , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
              => mm
              -> Map (Loc VarDeclE) Sort
              -> [LetVarDecl]
              -> Either Error (Map (Loc VarDeclE) Sort)
letInferTypes mm vdSId ls = do
    letVdSId <- accLetInferTypes (vdSId <.+> mm) ls
    return $ letVdSId `Map.union` vdSId
-}
{-
-- | Generic version of @letInferTypes@ that accumulates the partial results in
-- the composite map.
accLetInferTypes :: ( MapsTo Text Sort mm
                    , MapsTo (Loc VarDeclE)  Sort mm
                    , MapsTo (Loc FuncDeclE) FuncSignature mm
                    , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
                 => mm
                 -> [LetVarDecl]
                 -> Either Error (Map (Loc VarDeclE) Sort)
accLetInferTypes mm vs =
    case partitionEithers (inferVarDeclType mm <$> vs) of
        ([], rs) -> Right $ fromList rs <> innerMap mm
        (ls, []) -> Left $ Errors (fst <$> ls)
        (ls, rs) -> accLetInferTypes (fromList rs <.+> mm) (snd <$> ls)
-}

{-
-- | Get all the let variable declarations in a function.
letVarDeclsInFunc :: FuncDecl -> [[LetVarDecl]]
letVarDeclsInFunc fd = expLetVarDecls (funcBody fd)
-}

{-
-- | Infer the type of a variable declaration.
inferVarDeclType :: ( MapsTo Text Sort mm
                    , MapsTo (Loc VarDeclE) Sort mm
                    , MapsTo (Loc FuncDeclE) FuncSignature mm
                    , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
                 => mm
                 -> LetVarDecl -> Either (Error, LetVarDecl) (Loc VarDeclE, Sort)
inferVarDeclType mm vd = left (,vd) $
    case letVarDeclSortName vd of
    Just sn -> do -- If the sort is declared, we just return it.
        s <- findSort mm sn
        return (getLoc vd, s)
    Nothing -> do -- If the sort is not declared, we try to infer it from the expression.
        expSids <- inferExpTypes mm (varDeclExp vd)
        expSid <- getUniqueElement expSids
        return (getLoc vd, expSid)
-}

{-
-- | Infer the type of an expression. Due to function overloading an expression
-- could have multiple types, e.g.:
--
-- > fromString("33")
--
-- Could be a TorXakis 'Int', 'String', 'Bool', or even an 'ADT'.
--
inferExpTypes :: ( MapsTo Text Sort mm
                 , MapsTo (Loc VarDeclE) Sort mm
                 , MapsTo (Loc FuncDeclE) FuncSignature mm
                 , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
              => mm
              -> ExpDecl
              -> Either Error [Sort]
inferExpTypes mm ex =
    case expChild ex of
    VarRef _ l ->
        -- Find the location of the variable reference
        -- If it is a variable, return the sort of the variable declaration.
        -- If it is a function, return the return sort's of the functions.
        (fmap pure . (`lookup` mm) ||| findFuncReturnSorts mm)
            =<< (lookup l mm :: Either Error (Either (Loc VarDeclE) [Loc FuncDeclE]))
    ConstLit c ->
        return $ -- The type of any is any sort known!
            maybe (values @Text mm) pure (sortConst c)
    LetExp vss subEx -> do
        vdsSid <- foldM (letVarTypes mm) Map.empty (toList <$> vss)
        inferExpTypes (vdsSid <.+> mm) subEx
    If e0 e1 e2 -> do
        [se0s, se1s, se2s] <- traverse (inferExpTypes mm) [e0, e1, e2]
        when (SortBool `notElem` se0s)
            (Left Error
                { _errorType = TypeMismatch
                , _errorLoc  = getErrorLoc e0
                , _errorMsg  = "Guard expression must be a Boolean."
                           <> " Got " <> T.pack (show se0s)
                })
        let ses = se1s `intersect` se2s
        when (null ses)
            (Left Error
                { _errorType = TypeMismatch
                , _errorLoc  = getErrorLoc ex
                , _errorMsg  = "The sort of the two IF branches don't match."
                           <> "(" <> T.pack (show se1s)
                           <>" and " <> T.pack (show se2s) <> ")"
                }
             )
        return ses
    Fappl _ l exs -> concat <$> do
        sess <- traverse (inferExpTypes mm) exs
        for (sequence sess) $ \ses -> do
              fdis <- findFuncDecl mm l
              let matchingFdis = determineF mm fdis ses Nothing
              for matchingFdis $ \fdi -> do
                  sig  <- lookup fdi mm
                  when (ses /= args sig)
                      (Left Error
                       { _errorType = TypeMismatch
                       , _errorLoc  = getErrorLoc l
                       , _errorMsg  = "Function arguments sorts do not match "
                                     <> T.pack (show ses)
                       })
                  return $ returnSort sig
-}

{-
-- | Determine the types of variables in a let-expression.
letVarTypes :: ( MapsTo Text Sort mm
               , MapsTo (Loc VarDeclE) Sort mm
               , MapsTo (Loc FuncDeclE) FuncSignature mm
               , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
            => mm
            -> Map (Loc VarDeclE) Sort
            -> [LetVarDecl]
            -> Either Error (Map (Loc VarDeclE) Sort)
letVarTypes mm vdSid vs = do
    vsSidss <- traverse (inferExpTypes (vdSid <.+> mm)) (varDeclExp <$> vs)
    -- Here we make sure that each variable expression has a unique type.
    vsSids <- traverse getUniqueElement vsSidss
    let vdSid' = Map.fromList $ zip (getLoc <$> vs) vsSids
    -- 'Map.union' is left biased, so the new variables will shadow the previous ones.
    return $ vdSid' `Map.union` vdSid
-}

-- | @Sort@ of a constant.
sortConst :: Const -> Maybe Sort
sortConst (BoolConst _)   = Just SortBool
sortConst (IntConst _ )   = Just SortInt
sortConst (StringConst _) = Just SortString
-- Any does not have a sort associated with it.
--
-- Note that it seems like a bad design decision to change 'AnyConst' to
-- include the 'Sort', since the parser does not need to know anything about
-- the internal representations used by 'TorXakis'.
sortConst AnyConst        = Nothing

-- | Check that the two sorts match.
checkSorts :: Sort -> Sort -> Either Error ()
checkSorts s0 s1 =
    when (s0 /= s1) $ Left Error
    { _errorType = TypeMismatch
    , _errorLoc  = NoErrorLoc
    , _errorMsg  = "Sorts do not match "
                  <> T.pack (show s0) <> T.pack (show s1)
    }

-- | An expression has typed-variables if a map can be found from the location
-- of variable declarations, to their associated @SortId@.
class HasTypedVars mm e where
    inferVarTypes :: mm -> e -> CompilerM [(Loc VarDeclE, Sort)]

instance MapsTo Text Sort mm => HasTypedVars mm VarDecl where
    inferVarTypes mm vd = pure . (getLoc vd,) <$> mm .@!! varDeclSort vd

{- not yet needed: chanId / procId
instance ( MapsTo Text Sort mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         , MapsTo (Loc VarDeclE) Sort mm
         , MapsTo (Loc FuncDeclE) FuncSignature mm
         , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
         , MapsTo (Loc ChanDeclE) ChanId mm
         , MapsTo ProcId () mm
         ) => HasTypedVars mm BExpDecl where
    inferVarTypes _ Stop =
        return []
    inferVarTypes mm (ActPref _ ao be) = do
        xs <- inferVarTypes mm ao
        -- The implicit variables in the offers are needed in subsequent expressions.
        ys <- inferVarTypes (Map.fromList xs <.+> mm) be
        return $ xs ++ ys
    inferVarTypes mm (LetBExp vss be) = do
        vssVarTypes <- foldM (inferLetVarTypes mm) [] (toList <$> vss)
        beVarTypes  <- inferVarTypes (vssVarTypes <.++> mm) be
        return $ vssVarTypes ++ beVarTypes
    inferVarTypes mm (Pappl _ _ _ exs) =
        inferVarTypes mm exs
    inferVarTypes mm (Par _ _ be0 be1) =
        (++) <$> inferVarTypes mm be0 <*> inferVarTypes mm be1
    inferVarTypes mm (Enable _ be0 (Accept _ ofrs be1)) = do
        xs <- inferVarTypes mm be0
        es <- exitSort (xs <.++> mm) be0
        let sIds = exitSortIds es
        when (length ofrs /= length sIds)
            (throwError Error
                { _errorType = TypeMismatch
                , _errorLoc  = NoErrorLoc
                , _errorMsg  = "Exit sorts and offers don't match:\n"
                               <> "Offers: " <> T.pack (show ofrs)
                               <> "Exit sorts: " <> T.pack (show sIds)
                })
        let ofrs' = addType <$> zip sIds ofrs
        ys <- inferVarTypes mm ofrs'
        zs <- inferVarTypes (Map.fromList ys <.+> mm) be1
        return $ xs ++ ys ++ zs
        where
          -- Add the sort id's to the list of offers
          addType :: (SortId , ChanOfferDecl) -> ChanOfferDecl
          addType (sId, QuestD ivd) =
              QuestD $ mkIVarDecl (varName ivd)
                                  (getLoc ivd)
                                  (Just $ mkOfSort (SortId.name sId) (locFromLoc (getLoc ivd)))
          addType (_, excl) = excl
    inferVarTypes mm (Enable _ be0 be1) =
        (++) <$> inferVarTypes mm be0 <*> inferVarTypes mm be1
    -- The enable operator has to take care of handle the `Accept` constructor.
    -- If 'ACCEPT' does not follow an enable operator then an error will be
    -- thrown.
    inferVarTypes _ (Accept l _ _)     =
        throwError Error
            { _errorType = ParseError
            , _errorLoc  = getErrorLoc l
            , _errorMsg  = "ACCEPT cannot be used here."
            }
    inferVarTypes mm (Disable _ be0 be1) =
        (++) <$> inferVarTypes mm be0 <*> inferVarTypes mm be1
    inferVarTypes mm (Interrupt _ be0 be1) =
        (++) <$> inferVarTypes mm be0 <*> inferVarTypes mm be1
    inferVarTypes mm (Choice _ be0 be1) =
        (++) <$> inferVarTypes mm be0 <*> inferVarTypes mm be1
    inferVarTypes mm (Guard ex be) =
        (++) <$> inferVarTypes mm ex <*> inferVarTypes mm be
    inferVarTypes mm (Hide _ _ be) =
        inferVarTypes mm be
-}

{-
instance ( MapsTo Text Sort mm
         , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
         , MapsTo (Loc ChanDeclE) ChanId mm
         , MapsTo (Loc VarDeclE) Sort mm
         , MapsTo (Loc FuncDeclE) FuncSignature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         , MapsTo ProcId () mm
         ) => HasTypedVars mm ActOfferDecl where
    inferVarTypes mm (ActOfferDecl os mEx) = do
        xs <- inferVarTypes mm os
        -- The offers can introduce typed variables which can be referred to in
        -- the guard. That is why we need to infer the types in the offers, and
        -- use these to infer the types of the variable expressions.
        ys <- inferVarTypes (xs <.++> mm) mEx
        return $ xs ++ ys
-}

instance ( HasTypedVars mm e ) => HasTypedVars mm (Maybe e) where
    inferVarTypes mm = maybe (return []) (inferVarTypes mm)

instance ( HasTypedVars mm e ) => HasTypedVars mm [e] where
    inferVarTypes mm es = concat <$> traverse (inferVarTypes mm) es

    {-
instance ( MapsTo Text Sort mm
         , MapsTo (Loc VarDeclE) Sort mm
         , MapsTo (Loc FuncDeclE) FuncSignature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         ) => HasTypedVars mm ExpDecl where
    inferVarTypes mm ex = case expChild ex of
        VarRef {} -> return []
        ConstLit {} ->  return []
        LetExp vss subEx -> do
            vssVarTypes <- foldM (inferLetVarTypes mm) [] (toList <$> vss)
            subExVarTypes <- inferVarTypes (vssVarTypes <.++> mm) subEx
            return $ subExVarTypes ++ vssVarTypes
        If e0 e1 e2 -> concat <$> traverse (inferVarTypes mm) [e0, e1, e2]
        Fappl _ _ exs -> concat <$> traverse (inferVarTypes mm) exs

instance (MapsTo Text Sort mm
         , MapsTo (Loc VarDeclE) Sort mm
         , MapsTo (Loc FuncDeclE) FuncSignature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         ) => HasTypedVars mm LetVarDecl where
    inferVarTypes mm = liftEither. (fst +++ pure) . inferVarDeclType mm

instance ( MapsTo Text Sort mm
         , MapsTo (Loc VarDeclE) Sort mm
         , MapsTo (Loc FuncDeclE) FuncSignature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         ) => HasTypedVars mm ParLetVarDecl where
    inferVarTypes mm = inferLetVarTypes mm [] . toList

inferLetVarTypes :: ( MapsTo Text Sort mm
                    , MapsTo (Loc VarDeclE) Sort mm
                    , MapsTo (Loc FuncDeclE) FuncSignature mm
                    , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
                    )
                 => mm
                 -> [(Loc VarDeclE, Sort)]
                 -> [LetVarDecl]
                 -> CompilerM [(Loc VarDeclE, Sort)]
inferLetVarTypes mm vdSId vs = do
    vdSId' <- liftEither $
        Map.toList <$> accLetInferTypes (vdSId <.++> mm) vs
    return $ vdSId' ++ vdSId
-}

{- chanId -- not yet needed
instance ( MapsTo Text SortId mm
         , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
         , MapsTo (Loc ChanDeclE) ChanId mm
         , MapsTo (Loc VarDeclE) SortId mm
         , MapsTo (Loc FuncDeclE) Signature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         , MapsTo ProcId () mm
         ) => HasTypedVars mm OfferDecl where
    inferVarTypes mm (OfferDecl cr os) = do
        chId <- lookupChId mm (getLoc cr)
        -- Collect the variable declarations to @SortId@ maps from the output
        -- offers of the form 'Ch ! exp'.
        exclVds <- inferVarTypes mm os
        let
            -- Variables declared by the question offer.
            vds :: [Maybe (Loc VarDeclE, SortId)]
            vds = zipWith (\o sId -> (, sId) . getLoc <$> chanOfferIvarDecl o)
                          os
                          (chansorts chId)
        return $ catMaybes vds ++ exclVds
-}

{-
instance ( MapsTo Text SortId mm
         , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
         , MapsTo (Loc ChanDeclE) ChanId mm
         , MapsTo (Loc VarDeclE) SortId mm
         , MapsTo (Loc FuncDeclE) Signature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         , MapsTo ProcId () mm
         ) =>  HasTypedVars mm ChanOfferDecl where
    -- We don't have the @SortId@ of the variable, so we cannot know its type
    -- at this level. Refer to the 'instance HasTypedVars OfferDecl' to see how
    -- this is handled.
    inferVarTypes mm (QuestD vd) = case ivarDeclSort vd of
        Nothing -> return []
        Just sr ->
            pure . (getLoc vd, ) <$> (mm .@!! (sortRefName sr, getLoc sr))
    inferVarTypes mm (ExclD ex)         = inferVarTypes mm ex
-}

sorts :: (MapsTo Text Sort mm) => mm -> [OfSort] -> CompilerM [Sort]
sorts mm xs = traverse (mm .@!!) $ zip (sortRefName <$> xs) (getLoc <$> xs)

{-
-- | The expression has exit sorts associated to it.
class HasExitSorts e where
    -- | Obtain the exit sorts for an expression.
    exitSort :: ( MapsTo Text SortId mm
                , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
                , MapsTo (Loc ChanDeclE) ChanId mm
                , MapsTo ProcId () mm
                , MapsTo (Loc VarDeclE) SortId mm
                , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
                , MapsTo (Loc FuncDeclE) Signature mm
                )
             => mm -> e -> CompilerM ExitSort

instance HasExitSorts BExpDecl where
    exitSort _ Stop = return NoExit
    exitSort mm (ActPref l aos be) = do
        es0 <- exitSort mm aos
        es1 <- exitSort mm be
        (es0 <<+>> es1) <!!> l
    exitSort mm (LetBExp _ be) = exitSort mm be
    exitSort mm (Pappl n l crs exps) = do
        chIds <- chRefsToIds mm crs
        -- Cartesian product of all the possible sorts that can be inferred:
        expsSidss <- sequence <$> liftEither (traverse (inferExpTypes mm) exps)
        let candidate :: ProcId -> Bool
            candidate pId =
                   toText   n                     == ProcId.name pId
                && procchans pId == fmap (ChanSort . chansorts) chIds -- Compare the sort id's of the channels
                && procvars pId `elem` expsSidss
        case filter candidate $ keys @ProcId @() mm of
            [pId] -> return $ procexit pId
            []    -> throwError Error
                { _errorType = Undefined Process
                , _errorLoc  = getErrorLoc l
                , _errorMsg  = "No matching process found"
                }
            ps    -> throwError Error
                { _errorType = MultipleDefinitions Process
                , _errorLoc  = getErrorLoc l
                , _errorMsg  = "Multiple matching processes found: " <> T.pack (show ps)
                }
    exitSort mm (Par l _ be0 be1) = do
        es0 <- exitSort mm be0
        es1 <- exitSort mm be1
        (es0 <<->> es1) <!!> l
    exitSort mm (Enable _ _ be) = exitSort mm be
    exitSort mm (Accept _ _ be) = exitSort mm be
    exitSort mm (Disable l be0 be1) = addExitSorts mm l be0 be1
    exitSort mm (Interrupt l be0 be1) = do
        es1 <- exitSort mm be1
        when (es1 /= Exit [])
            (throwError Error
                { _errorType = TypeMismatch
                , _errorLoc  = NoErrorLoc
                , _errorMsg  = "\nTXS2233: " <> T.pack (show l)
                               <> ". Exit sorts do not match in Interrupt."
                })
        exitSort mm be0
    exitSort mm (Choice l be0 be1) = addExitSorts mm l be0 be1
    exitSort mm (Guard _ be) = exitSort mm be
    exitSort mm (Hide _ _ be) =
        exitSort mm be

addExitSorts :: ( HasErrorLoc l
                , HasExitSorts be1
                , HasExitSorts be0
                , MapsTo ProcId () mm
                , MapsTo Text SortId mm
                , MapsTo (Loc FuncDeclE) Signature mm
                , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
                , MapsTo (Loc VarDeclE) SortId mm, MapsTo (Loc ChanDeclE) ChanId mm
                , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm )
             => mm -> l -> be0 -> be1 -> CompilerM ExitSort
addExitSorts mm l be0 be1 = do
    es0 <- exitSort mm be0
    es1 <- exitSort mm be1
    (es0 <<+>> es1) <!!> l

instance HasExitSorts ActOfferDecl where
    exitSort mm (ActOfferDecl os _) =
        exitSort mm os

instance HasExitSorts e => HasExitSorts [e] where
    exitSort mm exps = do
        es <- traverse (exitSort mm) exps
        foldM (<<+>>) NoExit es

instance HasExitSorts OfferDecl where
    exitSort mm (OfferDecl cr ofrs) = case chanRefName cr of
        "EXIT"  -> Exit <$> traverse (offerSid mm) ofrs
        "ISTEP" -> return NoExit
        "QSTEP" -> return Hit
        "HIT"   -> return Hit
        "MISS"  -> return Hit
        _       -> return NoExit

-- | Combine exit sorts for choice, disable: max of exit sorts
(<<+>>) :: ExitSort -> ExitSort -> CompilerM ExitSort
NoExit   <<+>> NoExit    = return NoExit
NoExit   <<+>> Exit exs  = return $ Exit exs
NoExit   <<+>> Hit       = return Hit
Exit exs <<+>> NoExit    = return $ Exit exs
Exit exs <<+>> Exit exs' = do
    when (exs /= exs')
         (throwError Error
             { _errorType = TypeMismatch
             , _errorLoc  = NoErrorLoc
             , _errorMsg  = "\nTXS2222: Exit sorts do not match."
             })
    return (Exit exs)
Exit _   <<+>> Hit       = throwError Error
    { _errorType = TypeMismatch
    , _errorLoc  = NoErrorLoc
    , _errorMsg  = "\nTXS2223: Exit sorts do not match."
    }
Hit      <<+>> NoExit    = return Hit
Hit      <<+>> Exit _    = throwError Error
    { _errorType = TypeMismatch
    , _errorLoc  = NoErrorLoc
    , _errorMsg  = "TXS2224: Exit sorts do not match."
    }
Hit      <<+>> Hit       = return Hit


-- | Combine exit sorts for parallel: min of exit sorts
(<<->>) :: ExitSort -> ExitSort -> CompilerM ExitSort
NoExit   <<->> NoExit    = return NoExit
NoExit   <<->> Exit _    = return NoExit
NoExit   <<->> Hit       = return NoExit
Exit _   <<->> NoExit    = return NoExit
Exit exs <<->> Exit exs' = do
    when (exs /= exs')
         (throwError Error
             { _errorType = TypeMismatch
             , _errorLoc  = NoErrorLoc
             , _errorMsg  = "\nTXS2222: Exit sorts do not match."
             })
    return (Exit exs)
Exit _   <<->> Hit       = throwError Error
    { _errorType = TypeMismatch
    , _errorLoc  = NoErrorLoc
    , _errorMsg  = "\nTXS2223: Exit sorts do not match."
    }
Hit      <<->> NoExit    = return NoExit
Hit      <<->> Exit _    = throwError Error
    { _errorType = TypeMismatch
    , _errorLoc  = NoErrorLoc
    , _errorMsg  = "\nTXS2224: Exit sorts do not match."
    }
Hit      <<->> Hit       = return Hit

offerSid :: ( MapsTo Text SortId mm
            , MapsTo (Loc VarDeclE) SortId mm
            , MapsTo (Loc FuncDeclE) Signature mm
            , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm )
         => mm -> ChanOfferDecl -> CompilerM SortId
offerSid mm (QuestD vd) = case ivarDeclSort vd of
    Nothing -> throwError Error
        { _errorType = Missing Sort
        , _errorLoc = NoErrorLoc
        , _errorMsg = "No sort for offer variable" <> T.pack (show vd)
        }
    Just sr -> mm .@!! (sortRefName sr, sr)
offerSid mm (ExclD ex) = case inferExpTypes mm ex of
    Left err    -> throwError err
    Right []    -> throwError Error
        { _errorType = Unresolved Sort
        , _errorLoc  = NoErrorLoc
        , _errorMsg  = "No matching sort for " <> T.pack (show ex)
        }
    Right [sId] -> return sId
    Right xs    -> throwError Error
        { _errorType = Ambiguous Sort
        , _errorLoc  = NoErrorLoc
        , _errorMsg  = "Found multiple matching sorts for " <> T.pack (show ex)
                       <> ": " <> T.pack (show xs)
        }

instance ( MapsTo Text SortId mm
         , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
         , MapsTo (Loc ChanDeclE) ChanId mm
         , MapsTo (Loc VarDeclE) SortId mm
         , MapsTo (Loc FuncDeclE) Signature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         , MapsTo ProcId () mm
         ) => HasTypedVars mm Transition where
    inferVarTypes mm (Transition _ ofr _ _) = inferVarTypes mm ofr

instance ( MapsTo Text SortId mm
         , MapsTo (Loc ChanRefE) (Loc ChanDeclE) mm
         , MapsTo (Loc ChanDeclE) ChanId mm
         , MapsTo (Loc VarDeclE) SortId mm
         , MapsTo (Loc FuncDeclE) Signature mm
         , MapsTo (Loc VarRefE) (Either (Loc VarDeclE) [Loc FuncDeclE]) mm
         , MapsTo ProcId () mm
         ) => HasTypedVars mm TestGoalDecl where
    inferVarTypes mm gd = inferVarTypes mm (testGoalDeclBExp gd)
-}