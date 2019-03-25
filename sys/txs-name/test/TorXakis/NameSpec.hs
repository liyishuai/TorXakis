{-
TorXakis - Model Based Testing
Copyright (c) 2015-2017 TNO and Radboud University
See LICENSE at root directory of this repository.
-}
-----------------------------------------------------------------------------
-- |
-- Module      :  NameSpec
-- Copyright   :  (c) TNO and Radboud University
-- License     :  BSD3 (see the file license.txt)
-- 
-- Maintainer  :  pierre.vandelaar@tno.nl (Embedded Systems Innovation by TNO)
-- Stability   :  experimental
-- Portability :  portable
--
-- Test specifications for 'Name'.
-----------------------------------------------------------------------------
module TorXakis.NameSpec
(spec
)
where
import           Data.Either
import qualified Data.Text              as T


import           Test.Hspec
import           Test.QuickCheck

import           TorXakis.Language
import           TorXakis.Name

prop_empty :: Bool
prop_empty =
    case mkName (T.pack "") of
        Left _  -> True
        Right _ -> False

-- | match regex
-- note ^ and $ are line boundaries, so "\na" and "a\n" matches "^[A-Z_a-z][A-Z_a-z0-9-]*$".
-- we need entire text boundaries!
-- see http://hackage.haskell.org/package/regex-tdfa-1.2.3.1/docs/Text-Regex-TDFA.html
prop_regex :: String -> Bool
prop_regex str =
    let txt = T.pack str
      in if satisfyTxsIdentifier str
            then isRight $ mkName txt
            else isLeft $ mkName txt

spec :: Spec
spec = 
  describe "mkName (the smart constructor of Name)"$ do
    it "doesn't accept empty string" prop_empty
    it "does accept strings that adhere to regex" $ property prop_regex
