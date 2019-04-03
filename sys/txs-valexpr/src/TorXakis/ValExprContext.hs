{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
-----------------------------------------------------------------------------
-- |
-- Module      :  ValExprContext
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
--
-- Maintainer  :  pierre.vandelaar@tno.nl (Embedded Systems Innovation by TNO)
-- Stability   :  experimental
-- Portability :  portable
--
-- Context containing Value Expressions.
-----------------------------------------------------------------------------
module TorXakis.ValExprContext
( -- * Context
  ValExprContext
    -- dependencies, yet part of interface
, module TorXakis.FuncContext
, module TorXakis.VarContext
)
where
import           TorXakis.FuncContext
import           TorXakis.VarContext

-- | A ValExprContext instance contains all definitions to work with value expressions and references thereof
class (VarContext c, FuncContext c) => ValExprContext c