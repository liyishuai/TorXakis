module TorXakis.CompilerSpec where

import           Data.Either          (isRight)
import           Data.Foldable        (traverse_)
import qualified Data.Map             as Map
import           Data.Set             (Set)
import qualified Data.Set             as Set
import           System.FilePath      ((</>))
import           System.FilePath.Find (extension, find, (==?))
import           Test.Hspec           (Expectation, Spec, describe, it,
                                       parallel, runIO, shouldBe, shouldSatisfy)

import           FuncTable            (Signature, toMap)
import           Id                   (Id, Resettable, reset)
import           Sigs                 (Sigs, func, sort)
import           TxsAlex              (txsLexer)
import           TxsDefs              (TxsDefs, cstrDefs, funcDefs, sortDefs,
                                       varDefs)
import           TxsHappy             (txsParser)
import           VarId                (VarId)

import           TorXakis.Compiler    (compileFile)

spec :: Spec
spec =
    describe "Correctly compiles the incremental" $ do
        fs <- runIO $ find (return True) (extension ==? ".txs")
              ("test" </> "data" </> "success")
        parallel $ traverse_ testParser fs

    where
        testParser fp = it (show fp) $ do
            r <- compileFile fp
            -- First sanity check, the models are successfully compiled.
            r `shouldSatisfy` isRight
            let Right (_, tdefs, sigs) = r
            (_, tdefs', sigs') <- txsCompile fp
            -- Check that the 'TxsDef's generated by the `front` coincide with
            -- those generated by `txs-compiler`
            sortDefs tdefs ~==~ sortDefs tdefs'
            cstrDefs tdefs ~==~ cstrDefs tdefs'
            funcDefs tdefs ~==~ funcDefs tdefs'
            varDefs  tdefs ~==~ varDefs  tdefs'
            -- Check that the `Sigs` generated by `front` coincide with those
            -- generated by `txs-compiler`. We cannot test the handlers for
            -- equality, since they are functions.
            sort sigs ~==~ sort sigs'
            (Map.keys . toMap . func) sigs `shouldBe` (Map.keys . toMap . func) sigs'
            signatures sigs ~==~  signatures sigs'

                where
                  signatures :: Sigs VarId -> Set Signature
                  signatures = Set.fromList . concat . (Map.keys <$>) . Map.elems . toMap . func

-- | Equality modulo unique id's.
(~==~) :: (Resettable e, Show e, Eq e) => e -> e -> Expectation
e0 ~==~ e1 = reset e0 `shouldBe` reset e1

txsCompile :: FilePath -> IO (Id, TxsDefs, Sigs VarId)
txsCompile = (txsParser . txsLexer <$>) . readFile

