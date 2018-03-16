-- | 

module TorXakis.Compiler.Sigs where

import           Data.Map (Map)
import           Data.Text (Text)
import           Control.Arrow ((|||))
import           Control.Monad.Error.Class (throwError)
    
import           SortId (SortId, name)
import           Sigs    (Sigs (Sigs), sort, empty, func)
import           VarId   (VarId (VarId))
import           FuncTable (FuncTable (FuncTable))

import           TorXakis.Parser.Data
import           TorXakis.Compiler.Data
import           TorXakis.Compiler.FuncTable

adtDeclsToSigs :: Env -> [ADTDecl] -> CompilerM (Sigs VarId)
-- > data Sigs v = Sigs  { chan :: [ChanId]
-- >                     , func :: FuncTable v
-- >                     , pro  :: [ProcId]
-- >                     , sort :: Map.Map Text SortId
-- >                     } 
-- >
adtDeclsToSigs e ds =
    throwError ||| (\ft -> return $ empty { func = ft }) $
        compileToFuncTable e ds

funDeclsToSigs :: Env -> [FuncDecl] -> CompilerM (Sigs VarId)
funDeclsToSigs e ds =  throwError ||| (\ft -> return $ empty { func = ft }) $
        funcDeclsToFuncTable e ds

sortsToSigs :: Map Text SortId -> Sigs VarId
sortsToSigs sm = empty { sort = sm }
