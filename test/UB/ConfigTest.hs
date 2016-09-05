{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
module UB.ConfigTest (tests) where

import Test.Tasty
import Test.Tasty.HUnit
import Data.Aeson ((.:))
import qualified Data.Aeson as JSON
import qualified Data.Aeson.Types as JSON (typeMismatch)
import qualified Data.Set as Set

import UB.Prelude
import qualified UB.Config as SUT

data TestDbConfig
  = TestDbConfig Text Int Text Text Text
  deriving (Eq, Show)


readConfigFromFilesTests :: TestTree
readConfigFromFilesTests =
  testGroup "readConfigFromFiles"
    [ testCase "gives higher precedence to latter config files" <| do
        config <- SUT.readConfigFromFiles [ "test/fixtures/one.json"
                                          , "test/fixtures/two.json" ]

        -- config sources for the user key must be 2
        maybe
          (assertFailure "expected config entry user not present")
          (Set.size
           >> assertEqual "unexpected number of config source entries"
                          2)
          (SUT.getConfigSources ["user"] config)

        case SUT.getSelectedConfigSource ["user"] config of
          Nothing ->
            assertFailure "expected config entry host not present"

          Just (SUT.File index filepath value) -> do
            assertEqual "unexpected config file index" 1 index
            assertEqual "unexpected config file path" "test/fixtures/two.json" filepath
            assertEqual "unexpected config value" value (JSON.String "two")

          Just source ->
            assertFailure <| "Invalid config source returned " <> show source
        ]

resolveEnvVarsTests :: TestTree
resolveEnvVarsTests =
  testGroup "resolveEnvVars"
    [ testCase "gives higher precedence to env var values" <| do
        spec <- SUT.readConfigSpec "test/fixtures/spec.json"
        config0 <- SUT.readConfigFromFiles [ "test/fixtures/one.json"
                                           , "test/fixtures/two.json" ]

        config <- SUT.resolveEnvVars spec config0

        -- config sources for the user key must be 3
        maybe
          (assertFailure "expected config entry user not present")
          (Set.size
           >> assertEqual "unexpected number of config source entries"
                          3)
          (SUT.getConfigSources ["user"] config)

        case SUT.getSelectedConfigSource ["user"] config of
          Nothing ->
            assertFailure "expected config entry host not present"

          Just (SUT.EnvVar varname _value) -> do
            assertEqual "unexpected config env varname" "USER" varname

          Just source ->
            assertFailure <|
              "Invalid config source returned (expecting EnvVar)"
              <> show source

    , testCase "uses default value in case env var is not defined" <| do
        spec <- SUT.readConfigSpec "test/fixtures/spec.json"
        config0 <- SUT.readConfigFromFiles [ "test/fixtures/one.json"
                                           , "test/fixtures/two.json" ]

        config <- SUT.resolveEnvVars spec config0

        case SUT.getSelectedConfigSource ["password"] config of
          Nothing ->
            assertFailure "expected config entry password not present"

          Just (SUT.Default value) -> do
            assertEqual "unexpected config value default" (JSON.String "abc123") value

          Just source ->
            assertFailure <|
              "Invalid config source returned (expecting EnvVar)"
              <> show source
    ]

getConfigValueTests :: TestTree
getConfigValueTests =
  let
    dbParser json =
      case json of
        JSON.Object value ->
          TestDbConfig
            <$> value .: "host"
            <*> value .: "port"
            <*> value .: "name"
            <*> value .: "user"
            <*> value .: "password"
        _ ->
          JSON.typeMismatch "TestDbConfig" json
  in
    testGroup "getConfigValueWith"
      [ testCase "allows to fetch sub-maps and decode them" <| do
          spec <- SUT.readConfigSpec "test/fixtures/spec.json"
          config0 <- SUT.readConfigFromFiles [ "test/fixtures/one.json"
                                             , "test/fixtures/two.json" ]

          config <- SUT.resolveEnvVars spec config0
          case SUT.getConfigValueWith dbParser ["sub-system", "db"] config of
            Nothing ->
              assertFailure "Expected to parse a TestDbConfig record"

            Just dbConfig ->
              assertEqual "unexpected TestDbConfig values"
                          (TestDbConfig "localhost" 3306 "my_db" "my_db_user" "my_db_password")
                          dbConfig

        ]

tests :: TestTree
tests =
  testGroup "UB.Config"
    [ readConfigFromFilesTests
    , resolveEnvVarsTests
    , getConfigValueTests
    ]
