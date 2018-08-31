{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
-----------------------------------------------------------------------------
-- |
-- Module      :  SortADT
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
-- 
-- Maintainer  :  pierre.vandelaar@tno.nl (Embedded Systems Innovation by TNO)
-- Stability   :  experimental
-- Portability :  portable
--
-- Definitions for 'Sort' and Abstract Data Types.
--
-- We have to put 'Sort' and Abstract Data Types into one file 
-- because of the circular dependency caused by the 'Sort.SortADT' constructor.
-----------------------------------------------------------------------------
{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}
module TorXakis.SortADT
( -- * Sort
  Sort (..)
, isPrimitive

  -- * Abstract Data Types
  -- ** Field Definition
, FieldDef (..)
  -- ** Constructor Definition
, ConstructorDefView(..)
, ConstructorDef
, viewConstructorDef
, mkConstructorDef
  -- ** Abstract Data Type Definition
, ADTDefView (..)
, ADTDef
, viewADTDef
, mkADTDef
)
where

import           Control.DeepSeq     (NFData)
import           Data.Data           (Data)
import qualified Data.HashMap        as Map
import           Data.Text           (Text)
import qualified Data.Text           as T
import           GHC.Generics        (Generic)

import           TorXakis.Error      (Error(Error))
import           TorXakis.Name       (Name, repeatedByName, HasName, getName, RefByName, toMapByName)

-----------------------------------------------------------------------------
-- Sort
-----------------------------------------------------------------------------
-- | The data type that represents 'Sort'.
data Sort = SortBool
          | SortInt
          | SortChar
          | SortString
          | SortRegex
          | SortADT (RefByName ADTDef)
    deriving (Eq, Ord, Show, Read, Generic, NFData, Data)
-- If we want to make Sort package more flexible, we can use SortPrim "Int" & SortADT "WhatEver".

-- | Is the sort primitive?
isPrimitive :: Sort -> Bool
isPrimitive (SortADT _) = False
isPrimitive _           = True

-- | Data structure for a field definition.
data FieldDef = FieldDef
    { -- | Name of the field 
      fieldName :: Name
      -- | Sort of the field
    , sort      :: Sort
      -- | Meta data of the field
    , metadata  :: Text
    }
    deriving (Eq, Ord, Read, Show, Generic, NFData, Data)

instance HasName FieldDef where
    getName = fieldName

-- | The public view of 'ConstructorDef'.
data ConstructorDefView = ConstructorDefView
                        { -- | Name of the constructor
                          constructorName :: Name
                          -- | Field definitions of the constructor
                          --   Note that the position in the list is relevant as it represents implicit
                          --   the position of the fields in a constructor.
                        , fields :: [FieldDef]
                        }
    deriving (Eq, Ord, Read, Show, Generic, NFData, Data)

instance HasName ConstructorDefView where
    getName = constructorName

-- | ConstructorDefinition
newtype ConstructorDef = ConstructorDef { -- | View on constructor definition.
                                          viewConstructorDef :: ConstructorDefView
                                        }
  deriving (Eq, Ord, Read, Show, Generic, NFData, Data)

instance HasName ConstructorDef where
    getName = getName . viewConstructorDef

-- | Smart constructor for ConstructorDef
mkConstructorDef :: Name -> [FieldDef] -> Either Error ConstructorDef
mkConstructorDef n fs
    | not $ null nuFieldNames = Left $ Error (T.pack ("Non unique field names: " ++ show nuFieldNames))
    | otherwise               = Right $ ConstructorDef $ ConstructorDefView n fs
    where
        nuFieldNames :: [FieldDef]
        nuFieldNames = repeatedByName fs

-- | The public view of 'ADTDef'
data ADTDefView = ADTDefView
    { -- | Name of the ADT
      adtName      :: Name
      -- | Constructor definitions of the ADT
    , constructors :: Map.Map (RefByName ConstructorDef) ConstructorDef
    }
    deriving (Eq, Ord, Read, Show, Generic, NFData, Data)

instance HasName ADTDefView where
    getName = adtName

-- | Data structure for Abstract Data Type (ADT) definition.
newtype ADTDef = ADTDef { -- | View on 'ADTDEf'
                          viewADTDef :: ADTDefView
                        }
  deriving (Eq, Ord, Read, Show, Generic, NFData, Data)

instance HasName ADTDef where
    getName = getName . viewADTDef

-- | An ADTDef is returned when the following constraints are satisfied:
--
--   * List of 'ConstructorDef's is non-empty.
--
--   * Names of 'ConstructorDef's are unique
--
--   * Names of 'FieldDef's are unique across all 'ConstructorDef's
--
--   Otherwise an error is return. The error reflects the violations of any of the formentioned constraints.
mkADTDef :: Name -> [ConstructorDef] -> Either Error ADTDef
mkADTDef _ [] = Left $ Error (T.pack "Empty Constructor List")
mkADTDef m cs
    | not $ null nuCstrDefs   = Left $ Error (T.pack ("Non-unique constructor definitions" ++ show nuCstrDefs))
    | not $ null nuFieldNames = Left $ Error (T.pack ("Non-unique field definitions" ++ show nuFieldNames))
    | otherwise               = Right $ ADTDef $ ADTDefView m (toMapByName cs)
    where
        nuCstrDefs :: [ConstructorDef]
        nuCstrDefs   = repeatedByName cs
        
        nuFieldNames :: [FieldDef]
        nuFieldNames = repeatedByName (concatMap (fields . viewConstructorDef) cs)
