{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Protolude

import           Test.Tasty                   (defaultMainWithIngredients,
                                               testGroup)
import           Test.Tasty.Ingredients.Rerun (rerunningTests)
import           Test.Tasty.Runners           (consoleTestReporter,
                                               listingTests)

import qualified Etc.SpecTest
import qualified Etc.Resolver.FileTest

main :: IO ()
main =
  defaultMainWithIngredients
    [ rerunningTests [listingTests, consoleTestReporter] ]
    (testGroup "etc" [ Etc.SpecTest.tests
                     , Etc.Resolver.FileTest.tests ])
