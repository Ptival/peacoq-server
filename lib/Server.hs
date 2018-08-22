{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Server where

import           Control.Concurrent                          (forkIO, threadDelay)
import           Control.Monad                               (forever, forM)
import           Control.Monad.IO.Class                      (liftIO)
import           Data.ByteString                             (ByteString, append)
import qualified Data.HashMap.Strict                         as HM (map)
import           Data.IORef
import qualified Data.IntMap                                 as IM
import           Data.String.Utils
import           Data.Time.Format
import           Data.Time.LocalTime
import           Network.Socket
import           Prelude                                     hiding (log)
import           Snap.Core
import           Snap.Http.Server.Config
import           Snap.Snaplet
import           Snap.Snaplet.Session                        hiding (touchSession)
import           Snap.Snaplet.Session.Backends.CookieSession (initCookieSessionManager)
import           Snap.Snaplet.Session.SessionManager         ()
import           Snap.Util.FileServe
import           System.Directory
import           System.IO
import           System.Log.Formatter
import           System.Log.Handler                          (setFormatter)
import           System.Log.Handler.Simple
import           System.Log.Logger
import           System.Process

import           PeaCoq
import           PeaCoqHandler
import           Session

{- Configuration -}

configFile :: String
configFile = ".PeaCoqConfig.hs"

sessionTimeoutMinutes :: Int
sessionTimeoutMinutes = 15

disableCaching :: Handler b v a -> Handler b v a
disableCaching h = do
  modifyResponse $ setHeader "Cache-Control" "no-cache, no-store, must-revalidate"
  modifyResponse $ setHeader "Expires" "0"
  h

peacoqRoutes :: String -> [(ByteString, PeaCoqHandler ())]
peacoqRoutes dirToServe =
  [ ("coqtop", handlerCoqtop)
  , ("ping", handlerPing) -- we need this because we use HTTP
  , ("/", disableCaching $ serveDirectoryWith myDirConfig dirToServe)
  ]

{- End of configuration -}

data PeaCoqConfig =
  PeaCoqConfig
  { configUserId     :: String
  , configLogPath    :: FilePath
  , configSertop     :: String
  , configDirToServe :: String
  }
  deriving (Read, Show)

defaultPeaCoqConfig :: PeaCoqConfig
defaultPeaCoqConfig = PeaCoqConfig
  { configUserId     = "peacoq"
  , configLogPath    = "/tmp"
  , configSertop     = "coq-serapi/sertop.native --printer=sertop"
  , configDirToServe = "web/"
  }

serverConfig :: MonadSnap m => PeaCoqConfig -> String -> Config m a
serverConfig (PeaCoqConfig { configUserId = u, configLogPath = l }) nowString =
  setStartupHook hook -- figures out which port was used and prints it
  . setPort 0         -- 0 means that unless specified, pick a random port
  . setAccessLog (ConfigFileLog $ prefix ++ "access.log")
  . setErrorLog (ConfigFileLog $ prefix ++ "error.log")
  $ defaultConfig
  where
    prefix = l ++ "/" ++ u ++ "-" ++ nowString ++ "-"
    hook dat = do
      port <- socketPort . head $ getStartupSockets dat
      putStrLn $ "Server listening on port: " ++ show port
      --putStrLn $ "On recycle, visit: http://recycle.cs.washington.edu:" ++ show port
      --putStrLn $ "On attu, visit: http://attu.cs.washington.edu:" ++ show port
      --putStrLn $ "Otherwise, visit: http://localhost:" ++ show port

serve :: IO ()
serve = do
  now <- getZonedTime
  let nowString = formatTime defaultTimeLocale "%F-%H-%M-%S" now
  homeDir <- getHomeDirectory
  let configFilePath = concat [ homeDir, "/", configFile ]
  configExists <- doesFileExist configFilePath
  if not configExists
    then do
    error $ "File not found: " ++ configFilePath ++ "\nExample:\n" ++ show defaultPeaCoqConfig
    else return ()
  fileString <- readFile configFilePath
  let configString = unwords . filter (not <$> startswith "--") $ lines fileString
  let config@(PeaCoqConfig { configUserId
                           , configLogPath
                           , configSertop
                           , configDirToServe
                           }) = read configString
  handler <- fileHandler
            (configLogPath ++ "/" ++ configUserId ++ "-" ++ nowString ++ ".log")
            loggingPriority
  let format = simpleLogFormatter "[$time] $msg"
  let fHandler = setFormatter handler format
  updateGlobalLogger rootLoggerName (setLevel loggingPriority . addHandler fHandler)
  serveSnaplet (serverConfig config nowString) (peaCoqSnaplet configSertop configDirToServe)

sessionTimeoutSeconds :: Int
sessionTimeoutSeconds = 60 * sessionTimeoutMinutes

sessionTimeoutMicroseconds :: Int
sessionTimeoutMicroseconds = sessionTimeoutSeconds * 1000 * 1000

loggingPriority :: Priority
loggingPriority = INFO

closeSession :: String -> SessionState -> IO ()
closeSession _hash (SessionState _ (hi, ho, _, ph)) = do
  --logAction hash $ "END SESSION " ++ show sessId
  hClose hi
  hClose ho
  terminateProcess ph -- not stricly necessary
  _ <- waitForProcess ph
  return ()

cleanStaleSessions :: String -> IORef GlobalState -> IO ()
cleanStaleSessions hash globRef = forever $ do
  sessionsToClose <- atomicModifyIORef' globRef markAndSweep
  _ <- forM sessionsToClose (closeSession hash)
  threadDelay sessionTimeoutMicroseconds
  where
    markAndSweep :: GlobalState -> (GlobalState, [SessionState])
    markAndSweep gs =
      let (alive, stale) = IM.partition isAlive (gActiveSessions gs) in
      (gs { gActiveSessions = IM.map markStale alive }, IM.elems stale)

newPeaCoqGlobalState :: String -> String -> IO (IORef GlobalState)
newPeaCoqGlobalState coqtop hash = liftIO $ do
  globRef <- newIORef $ GlobalState 0 IM.empty coqtop
  -- spawn a parallel thread to regularly clean up
  _ <- forkIO $ cleanStaleSessions hash globRef
  return globRef

globRefInit :: IORef GlobalState -> SnapletInit PeaCoq PeaCoqGlobRef
globRefInit globRef =
  makeSnaplet "globRef" "Holds PeaCoq's global state IORef" Nothing $ do
    return globRef

hashInit :: String -> SnapletInit PeaCoq PeaCoqHash
hashInit hash =
  makeSnaplet "hash" "Holds the current git commit hash" Nothing $ do
    return hash

peaCoqSnaplet :: String -> String -> SnapletInit PeaCoq PeaCoq
peaCoqSnaplet coqtop dirToServe = makeSnaplet "PeaCoq" "PeaCoq" Nothing $ do
  hash <- liftIO $ getGitCommitHash
  globRef <- liftIO $ newPeaCoqGlobalState coqtop hash
  g <- nestSnaplet "globRef" lGlobRef $ globRefInit globRef
  h <- nestSnaplet "hash" lHash $ hashInit hash
  s <- nestSnaplet "session" lSession cookieSessionManager
  addRoutes $ peacoqRoutes dirToServe
  return $ PeaCoq g h s
  where
    cookieSessionManager :: SnapletInit PeaCoq SessionManager
    cookieSessionManager =
      initCookieSessionManager "encryption_key" "peacoq_session" Nothing Nothing

myDirConfig :: DirectoryConfig (Handler PeaCoq PeaCoq)
myDirConfig =
  defaultDirectoryConfig
  { mimeTypes = HM.map (\ m -> append m "; charset=utf-8") defaultMimeTypes
  , indexFiles = ["index.html"]
  }
