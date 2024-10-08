{-# LANGUAGE CPP               #-}
{-# LANGUAGE TemplateHaskell   #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Wrappers for generating prologue and epilogue code in Haskell.
module JsonToType.CodeGen.Haskell(
    writeHaskellModule
  , runHaskellModule
  , runHaskellModuleStrict
  , defaultHaskellFilename
  , importedModules
  , requiredPackages
  , generateModuleImports
  , ModuleImport
  ) where

import qualified Data.Text           as Text
import qualified Data.Text.IO        as Text
import           Data.Text hiding (unwords)
import qualified Data.HashMap.Strict as Map
import           Control.Arrow               (first)
import           Control.Exception (assert)
import           Data.Default
import           Data.Monoid                 ((<>))
import           System.FilePath
import           System.IO
import           System.Process                 (system)
import qualified System.Environment             (lookupEnv)
import           System.Exit                    (ExitCode)

import           JsonToType.Format
import           JsonToType.Type
import           JsonToType.CodeGen.Generic(src)
import           JsonToType.CodeGen.HaskellFormat
import           JsonToType.Util

import qualified Language.Haskell.RunHaskellModule as Run

-- | Default output filname is used, when there is no explicit output file path, or it is "-" (stdout).
-- Default module name is consistent with it.
defaultHaskellFilename :: FilePath
defaultHaskellFilename = "JSONTypes.hs"

-- | Generate module header
header :: Text -> Text
header moduleName = [src|
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE TypeOperators       #-}
{-# LANGUAGE DeriveGeneric       #-}
-- | DO NOT EDIT THIS FILE MANUALLY!
--   It was automatically generated by `json-to-type`.
module |] <> capitalize moduleName <> [src| where
|] <> generateModuleImports importedModules

-- | Alias for indicating that this is item in module imports list.
type ModuleImport = Text

-- | Given a list of imports, generate source code.
generateModuleImports :: [ModuleImport] -> Text
generateModuleImports  = Text.unlines
                       . fmap ("import " <>)

-- | List of packages required by modules below.
--   Keep and maintain together.
requiredPackages :: [Text]
requiredPackages = ["aeson", "json-alt", "base", "bytestring", "text"]

-- | List of modules to import
importedModules :: [ModuleImport]
importedModules = [
    "          System.Exit        (exitFailure, exitSuccess)"
  , "          System.IO          (stderr, hPutStrLn)"
  , "qualified Data.ByteString.Lazy.Char8 as BSL"
  , "          System.Environment (getArgs)"
  , "          Control.Monad      (forM_, mzero, join)"
  , "          Control.Applicative"
  , "          JsonToType.Alternative"
  , "          Data.Aeson(eitherDecode, Value(..), FromJSON(..), ToJSON(..),pairs,(.:), (.:?), (.=), object)"
  , "          Data.Monoid((<>))"
  , "          Data.Text (Text)"
  , "qualified GHC.Generics"
  ]

-- | Epilogue for generated code:
--
--   * function to use parser to get data from `Text`
--   * main function in case we use `runghc` for testing parser immediately
epilogue :: Text -> Text
epilogue toplevelName = [src|

-- | Use parser to get |] <> toplevelName <> [src| object
parse :: FilePath -> IO |] <> toplevelName <> [src|
parse filename = do
    input <- BSL.readFile filename
    case eitherDecode input of
      Left errTop -> fatal $ case (eitherDecode input :: Either String Value) of
                           Left  err -> "Invalid JSON file: " ++ filename ++ "\n   " ++ err
                           Right _   -> "Mismatched JSON value from file: " ++ filename
                                     ++ "\n" ++ errTop
      Right r     -> return (r :: |] <> toplevelName <> ")" <> [src|
  where
    fatal :: String -> IO a
    fatal msg = do hPutStrLn stderr msg
                   exitFailure

-- | For quick testing
main :: IO ()
main = do
  filenames <- getArgs
  forM_ filenames (\f -> parse f >>= (\p -> p `seq` putStrLn $ "Successfully parsed " ++ f))
  exitSuccess
|]

-- | Write a Haskell module to an output file, or stdout if `-` filename is given.
writeHaskellModule :: FilePath -> Text -> Map.HashMap Text Type -> IO ()
writeHaskellModule outputFilename toplevelName types =
    withFileOrHandle outputFilename WriteMode stdout $ \hOut ->
      assert (extension == ".hs") $ do
        Text.hPutStrLn hOut $ header $ Text.pack moduleName
        -- We write types as Haskell type declarations to output handle
        Text.hPutStrLn hOut $ displaySplitTypes types
        Text.hPutStrLn hOut $ epilogue toplevelName
  where
    (moduleName, extension) =
       first normalizeTypeName'     $
       splitExtension               $
       if     outputFilename == "-"
         then defaultHaskellFilename
         else outputFilename
    normalizeTypeName' = Text.unpack . normalizeTypeName . Text.pack

-- | Function to run Haskell module
--
--   FIXME: just rely on `run-haskell-module` exports
runHaskellModule :: FilePath -> [String] -> IO ExitCode
runHaskellModule = Run.runHaskellModule

-- | Options to be used when running Haskell module
defaultHaskellOpts :: Run.RunOptions
defaultHaskellOpts  = def { Run.additionalPackages = ["json-alt", "aeson"]
                          }

-- | Run Haskell module with strict warning options (each warning is an error)
runHaskellModuleStrict :: FilePath -> [String] -> IO ExitCode
runHaskellModuleStrict = Run.runHaskellModule' opts
  where
      opts = def { Run.compileArgs = ["-Wall", "-Werror"]}

