{-# LANGUAGE CPP               #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Code generation and test running in different languages. (Switchbox.)
module JsonToType.CodeGen(
    Lang(..)
  , writeModule
  , runModule
  , defaultOutputFilename
  ) where

import           Data.Text(Text)
import qualified Data.HashMap.Strict as Map
import           JsonToType.Type
import           System.Exit

import           JsonToType.CodeGen.Haskell
import           JsonToType.CodeGen.Elm

-- | Available output languages.
data Lang = Haskell
          | HaskellStrict
          | Elm

-- | Default output filname is used, when there is no explicit output file path, or it is "-" (stdout).
-- Default module name is consistent with it.
defaultOutputFilename :: Lang -> FilePath
defaultOutputFilename Haskell       = defaultHaskellFilename
defaultOutputFilename HaskellStrict = defaultHaskellFilename
defaultOutputFilename Elm           = defaultElmFilename

-- | Write a Haskell module to an output file, or stdout if `-` filename is given.
writeModule :: Lang -> FilePath -> Text -> Map.HashMap Text Type -> IO ()
writeModule Haskell       = writeHaskellModule
writeModule HaskellStrict = writeHaskellModule
writeModule Elm           = writeElmModule

-- | Run module in a given language.
runModule :: Lang -> FilePath -> [String] -> IO ExitCode
runModule Haskell       = runHaskellModule
runModule HaskellStrict = runHaskellModuleStrict
runModule Elm           = runElmModule
