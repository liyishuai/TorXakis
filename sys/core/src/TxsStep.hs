{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}

-- ----------------------------------------------------------------------------------------- --
-- |
-- Module      :  TxsCore
-- Copyright   :  TNO and Radboud University
-- License     :  BSD3
-- Maintainer  :  jan.tretmans
-- Stability   :  experimental
--
-- Core Module TorXakis API:
-- API for TorXakis core functionality.
-- ----------------------------------------------------------------------------------------- --

-- {-# LANGUAGE OverloadedStrings #-}

module TxsStep

( txsSetStep     -- :: TxsDefs.ModelDef -> IOC.IOC (Either String ())
, txsShutStep    -- :: IOC.IOC (Either String ())
, txsStartStep   -- :: IOC.IOC (Either String ())
, txsStopStep    -- :: IOC.IOC (Either String ())
, txsStepRun     -- :: Int -> IOC.IOC (Either String TxsDDefs.Verdict)
, txsStepAct     -- :: TxsDDefs.Action -> IOC.IOC (Either String TxsDDefs.Verdict)
)


{-

 SetStepper  ::   Model    modelname    :: String     -- start stepper with model
                    | Mapper   mappername   :: String     -- start stepper with mapper
                    | Purp     purpname     :: String     -- start stepper with goal
                    | Goals
                    |  TOBJ    goalname     :: String     -- or purpose
                    | Proc     procname     :: String     -- start stepper with process

, stpAct   Action | Offer | -
, stpObs
, stpRun   [NrSteps]

, stpGoInit
, stpGoTo   StateNr
, stpGoBack [NrSteps]

, stpMenu

, stpShowStNr
, stpShowState
, stpShowPath
, stpShowGraph
, stpShowTree
, stpShowTrace

-}


-- ----------------------------------------------------------------------------------------- --
-- import

where

-- import           Control.Arrow
-- import           Control.Monad
import           Control.Monad.State
-- import qualified Data.List           as List
import qualified Data.Map            as Map
-- import           Data.Maybe
-- import           Data.Monoid
-- import qualified Data.Set            as Set
-- import qualified Data.Text           as T
-- import           System.Random

-- import from local
import           CoreUtils
-- import           Ioco
import           Step

-- import           Config              (Config)
-- import qualified Config

-- import from behave(defs)
import qualified Behave
import qualified BTree
-- import           Expand              (relabel)

-- import from coreenv
import qualified EnvCore             as IOC
-- import qualified EnvData
-- import qualified ParamCore

-- import from defs
-- import qualified Sigs
import qualified TxsDDefs
import qualified TxsDefs
-- import qualified TxsShow
-- import           TxsUtils

-- import from solve
-- import qualified FreeVar
-- import qualified SMT
-- import qualified Solve
-- -- import qualified SolveDefs
-- import qualified SolveDefs.Params
-- import qualified SMTData

-- import from value
-- import qualified Eval

-- import from valexpr
-- import qualified SortId
-- import qualified SortOf
-- import ConstDefs
-- import VarId


-- ----------------------------------------------------------------------------------------- --
-- txsSetStep

-- | Set stepping using the provided model definition.
--
--   Only possible when txscore is initialized.
txsSetStep :: TxsDefs.ModelDef              -- ^ model definition.
           -> IOC.IOC (Either String ())
txsSetStep moddef  =  do
     envc <- get
     case IOC.state envc of
       IOC.Initing { IOC.smts     = smts
                   , IOC.tdefs    = tdefs
                   , IOC.sigs     = sigs
                   , IOC.putmsgs  = putmsgs
                   }
         -> do IOC.putCS IOC.StepSet { IOC.smts     = smts
                                     , IOC.tdefs    = tdefs
                                     , IOC.sigs     = sigs
                                     , IOC.modeldef = moddef
                                     , IOC.putmsgs  = putmsgs
                                     }
               return $ Right ()
       _ -> return $ Left "'txsSetStep' only allowed in 'Initing' core state"


-- ----------------------------------------------------------------------------------------- --
-- txsShutStep

-- | Shut stepping.
--
--   Only possible when txscore is in StepSet.
txsShutStep :: IOC.IOC (Either String ())
txsShutStep  =  do
     envc <- get
     case IOC.state envc of
       IOC.StepSet { IOC.smts     = smts
                   , IOC.tdefs    = tdefs
                   , IOC.sigs     = sigs
                   , IOC.putmsgs  = putmsgs
                   }
         -> do IOC.putCS IOC.Initing { IOC.smts     = smts
                                     , IOC.tdefs    = tdefs
                                     , IOC.sigs     = sigs
                                     , IOC.putmsgs  = putmsgs
                                     }
               return $ Right ()
       _ -> return $ Left "'txsShutStep' only allowed in 'StepSet' core state"

                 
-- ----------------------------------------------------------------------------------------- --
-- txsStartStep

-- | Start stepping.
--
--   Only possible when txscore is StepSet.
txsStartStep :: IOC.IOC (Either String ())
txsStartStep  =  do
     envc <- get
     case IOC.state envc of
       IOC.StepSet { IOC.smts     = smts
                   , IOC.tdefs    = tdefs
                   , IOC.sigs     = sigs
                   , IOC.modeldef = moddef
                   , IOC.putmsgs  = putmsgs
                   }
         -> do IOC.putCS IOC.Stepping { IOC.smts      = smts
                                      , IOC.tdefs     = tdefs
                                      , IOC.sigs      = sigs
                                      , IOC.modeldef  = moddef
                                      , IOC.behtrie   = []
                                      , IOC.inistate  = 0
                                      , IOC.curstate  = 0
                                      , IOC.maxstate  = 0
                                      , IOC.modstss   = Map.empty
                                      , IOC.putmsgs   = putmsgs
                                      }
               maybt <- startStepper moddef
               case maybt of
                 Nothing
                   -> return $ Left "'txsStartStep': starting the 'stepper' failed"
                 Just bt
                   -> do IOC.modifyCS $ \st -> st { IOC.modstss = Map.singleton 0 bt }
                         return $ Right ()
       _ -> return $ Left "'txsStartStep' only allowed in 'StepSet' core state"


startStepper :: TxsDefs.ModelDef ->
                IOC.IOC ( Maybe BTree.BTree )

startStepper (TxsDefs.ModelDef minsyncs moutsyncs msplsyncs mbexp)  =  do
     let allSyncs = minsyncs ++ moutsyncs ++ msplsyncs
     envb            <- filterEnvCtoEnvB
     (maybt', envb') <- lift $ runStateT (Behave.behInit allSyncs mbexp) envb
     writeEnvBtoEnvC envb'
     return maybt'


-- ----------------------------------------------------------------------------------------- --
-- txsStopStep

-- | stop stepping.
--
--   Only possible when Stepping.
txsStopStep :: IOC.IOC (Either String ())
txsStopStep  =  do
     envc <- get
     case  IOC.state envc of
       IOC.Stepping { IOC.smts     = smts
                    , IOC.tdefs    = tdefs
                    , IOC.sigs     = sigs
                    , IOC.modeldef = moddef
                    , IOC.putmsgs  = putmsgs
                    }
         -> do IOC.putCS IOC.StepSet { IOC.smts     = smts
                                     , IOC.tdefs    = tdefs
                                     , IOC.sigs     = sigs
                                     , IOC.modeldef = moddef
                                     , IOC.putmsgs  = putmsgs
                                     }
               return $ Right ()
       _ -> return $ Left "'txsStopStep' only allowed in 'Stepping' core state"


-- ----------------------------------------------------------------------------------------- --
-- txsStepRun

-- | Step model with the provided number of actions.
--
--   Only possible when Stepping.
txsStepRun :: Int                                        -- ^ Number of actions to step model.
           -> IOC.IOC (Either String TxsDDefs.Verdict)   -- ^ Verdict of stepping.
txsStepRun nrsteps  =  do
     envc <- get
     case IOC.state envc of
       IOC.Stepping {}
         -> do verd <- Step.stepN nrsteps 1
               return $ Right verd
       _ -> return $ Left "'txsStepRun' only allowed in 'Stepping' core state"


-- ----------------------------------------------------------------------------------------- --
-- txsStepAct

-- | Step model with the provided action.
--
--   Only possible when Stepping.
txsStepAct :: TxsDDefs.Action                            -- ^ Action to step in model.
           -> IOC.IOC (Either String TxsDDefs.Verdict)   -- ^ Verdict of stepping.
txsStepAct act  =  do
     envc <- get
     case IOC.state envc of
       IOC.Stepping {}
         -> do verd <- Step.stepA act
               return $ Right verd
       _ -> return $ Left "'txsStepAct' only allowed in 'Stepping' core state"


-- ----------------------------------------------------------------------------------------- --

{-

-- | Go to state with the provided state number.
-- core action.
--
-- Only possible in stepper modus (see 'txsSetStep').
txsGoTo :: EnvData.StateNr              -- ^ state to go to.
        -> IOC.IOC ()
txsGoTo stateNr  =
  if  stateNr >= 0
  then do
    modStss <- gets (IOC.modstss . IOC.state)
    case Map.lookup stateNr modStss of
       Nothing -> IOC.putMsgs [ EnvData.TXS_CORE_USER_ERROR "no such state" ]
       Just _ ->
         modify $
           \env ->
             env { IOC.state =
                     (IOC.state env)
                     { IOC.curstate = stateNr }
                 }
  else ltsBackN (-stateNr)
  where
     ltsBackN :: Int -> IOC.IOC ()
     ltsBackN backsteps
        | backsteps <= 0 = return ()
        | otherwise  = do    -- backsteps > 0
            st <- gets IOC.state
            let iniState = IOC.inistate st
                curState = IOC.curstate st
                behTrie = IOC.behtrie st
            case [ s | (s, _, s') <- behTrie, s' == curState ] of
              [prev] -> do
                modify $
                  \env ->
                    env { IOC.state =
                            (IOC.state env) {
                            IOC.curstate = prev
                            }
                        }
                unless (prev == iniState) (ltsBackN (backsteps-1))
              _      -> do
                IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "LtsBack error" ]
                return ()

-- | Provide the path.
txsPath :: IOC.IOC [(EnvData.StateNr, TxsDDefs.Action, EnvData.StateNr)]
txsPath  =  do
  st <- gets IOC.state
  path (IOC.inistate st) (IOC.curstate st)
  where
     path :: EnvData.StateNr -> EnvData.StateNr ->
             IOC.IOC [(EnvData.StateNr, TxsDDefs.Action, EnvData.StateNr)]
     path from to | from >= to = return []
     path from to = do -- from < to
       iniState <- gets (IOC.inistate . IOC.state)
       behTrie  <- gets (IOC.behtrie . IOC.state)
       case [ (s1,a,s2) | (s1,a,s2) <- behTrie, s2 == to ] of
         [(s1,a,s2)] ->
           if (s1 == from) || (s1 == iniState)
           then return [(s1,a,s2)]
           else do
             pp <- path from s1
             return $ pp ++ [(s1,a,s2)]
         _           -> do
           IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "Path error" ]
           return []


-- | Return the menu, i.e., all possible actions.
txsMenu :: String                               -- ^ kind (valid values are "mod", "purp", or "map")
        -> String                               -- ^ what (valid values are "all", "in", "out", or a <goal name>)
        -> IOC.IOC BTree.Menu
txsMenu kind what  =  do
     envSt <- gets IOC.state
     case (kind,envSt) of
       ("mod",IOC.Testing {})  -> do
            menuIn   <- Ioco.iocoModelMenuIn
            menuOut  <- Ioco.iocoModelMenuOut
            case what of
              "all" -> return $ menuIn ++ menuOut
              "in"  -> return menuIn
              "out" -> return menuOut
              _     -> do IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "error in menu" ]
                          return []
       ("mod",IOC.Simuling {}) -> do
            menuIn   <- Ioco.iocoModelMenuIn
            menuOut  <- Ioco.iocoModelMenuOut
            case what of
              "all" -> return $ menuIn ++ menuOut
              "in"  -> return menuIn
              "out" -> return menuOut
              _     -> do IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "error in menu" ]
                          return []
       ("mod",IOC.Stepping {}) -> do
            menuIn  <- Step.stepModelMenuIn
            menuOut <- Step.stepModelMenuOut
            case what of
              "all" -> return $ menuIn ++ menuOut
              "in"  -> return menuIn
              "out" -> return menuOut
              _     -> do IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "error in menu" ]
                          return []
       ("map",IOC.Testing {})  -> Mapper.mapperMenu
       ("map",IOC.Simuling {}) -> Mapper.mapperMenu
       ("purp",IOC.Testing {}) -> Purpose.goalMenu what
       _ -> do IOC.putMsgs [ EnvData.TXS_CORE_SYSTEM_ERROR "error in menu" ]
               return []

-}

-- ----------------------------------------------------------------------------------------- --
--                                                                                           --
-- ----------------------------------------------------------------------------------------- --
