{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
-----------------------------------------------------------------------------
-- |
-- Module      :  FreeVars
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
-- 
-- Maintainer  :  pierre.vandelaar@tno.nl (Embedded Systems Innovation by TNO)
-- Stability   :  experimental
-- Portability :  portable
--
-- Free Variables in element related functionality.
-- Free Variables is not equal to used variables due to scoping.
-- For example, the bound variable x in forall x . x > 0 is used but not free.
-----------------------------------------------------------------------------
module TorXakis.Var.FreeVars
( FreeVars (..)
  -- dependencies, yet part of interface
, Set.Set
, VarDef
, RefByName
)
where
import qualified Data.Set               as Set

import TorXakis.Name
import TorXakis.Var.VarDef

-- | Class for Used Variables
class FreeVars a where
    -- | Determine the used variables
    freeVars :: a -> Set.Set (RefByName VarDef)
    -- | Is element closed?
    -- A closed element has no used variables.
    isClosed :: a -> Bool
    isClosed = Set.null . freeVars