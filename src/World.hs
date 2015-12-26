{-# LANGUAGE ViewPatterns #-}
module World where

import qualified Data.Map as Map
import Data.Maybe
import Control.Monad.Reader
import System.Random

import Config
import Figures
import Util

type Grid = Map.Map GridPosition ()

data Hardness = Easy | Medium | Hard

-- | Data represents the state of the Tetris game
data TetrisGame = Game
  { fallingFigure   :: Figure
  , fallingPosition :: GridPosition
  , startFalling    :: GridPosition
  , width           :: Int
  , height          :: Int
  , nextFigures     :: [Figure]
  , grid            :: Grid
  , hardness        :: Hardness
  , isPause         :: Bool
  }

-- | Initial state of the game
initialState :: ReaderT AppConfig IO TetrisGame
initialState = do
  cfg <- ask
  gen <- liftIO getStdGen
  let fs = randomFigures gen
  let startPos = startPosition cfg
  return $ Game (head fs) startPos startPos (fst $ gridSize $ cfg) 
      (snd $ gridSize $ cfg) (tail fs) Map.empty Easy False

-- | Real position in Grid
getRealCoords :: Figure -> GridPosition -> [Block]
getRealCoords (Figure _ _ bs) curPos = map (sumPair curPos) bs

-- | List of random figures
randomFigures :: (RandomGen g) => g -> [Figure]
randomFigures gen = zipWith getFigures (randoms gen) (randoms gen)

-- | Sets the currently falling figure from nextFigures
nextFigureGame :: TetrisGame -> TetrisGame
nextFigureGame (Game (Figure ftype rot bs) fpos spos w h fs grid hrd isPs) = 
                          Game (head fs) spos spos w h (tail fs) updateGrid hrd isPs
  where
    updateGrid = foldl addToGrid grid bs
    addToGrid grid b = Map.insert b () grid
                            

-- | Shifts left a figure if able to
shiftLeftGame :: TetrisGame -> TetrisGame
shiftLeftGame curTetrisGame@(Game ff (shiftLeft -> fpos) spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = curTetrisGame
  

-- | Shifts right a figure if able to
shiftRightGame :: TetrisGame -> TetrisGame
shiftRightGame curTetrisGame@(Game ff (shiftRight -> fpos) spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = curTetrisGame

-- | Shifts down a figure if able to
shiftDownGame :: TetrisGame -> TetrisGame
shiftDownGame curTetrisGame@(Game ff (shiftDown -> fpos) spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = nextFigureGame curTetrisGame

-- | Checks that the point belongs to the Grid and that it is free.
goodCoords :: Grid -> Int -> Int -> [Block] -> Bool
goodCoords grid w h = all goodCoord
  where
    goodCoord (x,y) = x >= 0 && x < w && y >= 0 && y < h && isJust (Map.lookup (x,y) grid)
    
shiftRight :: GridPosition -> GridPosition
shiftRight = sumPair (1,0)

shiftLeft :: GridPosition -> GridPosition
shiftLeft = sumPair (-1,0)

shiftDown :: GridPosition -> GridPosition
shiftDown = sumPair (0,-1)