{-# LANGUAGE ViewPatterns #-}
module World where

import qualified Data.Map as Map
import Data.Maybe
import Control.Monad.Reader
import System.Random
import Data.List
import Data.Ord

import Config
import Figures
import Util

type Grid = Map.Map GridPosition ()

data Hardness = Easy | Medium | Hard
      deriving Show

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
  deriving Show

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
nextFigureGame (Game ff fpos spos w h fs grid hrd isPs) = Game (head fs) spos spos w h (tail fs) updateGrid hrd isPs
  where
    updateGrid = burnFullLines $ foldl addToGrid grid (getRealCoords ff fpos)
    addToGrid grid b = Map.insert b () grid
    burnFullLines = Map.fromList
      . (`zip` repeat ())
      . concat
      . filter ((/=w) . length)
      . groupBy (\(_,y1) (_,y2) -> y1 == y2)
      . sortBy (comparing snd)
      . Map.keys
      
-- | Shifts left a figure if able to
shiftLeftFigure :: TetrisGame -> TetrisGame
shiftLeftFigure curTetrisGame@(Game ff (shiftLeft -> fpos) spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = curTetrisGame


-- | Shifts right a figure if able to
shiftRightFigure :: TetrisGame -> TetrisGame
shiftRightFigure curTetrisGame@(Game ff (shiftRight -> fpos) spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = curTetrisGame

-- | Shifts down a figure if able to
shiftDownFigure :: TetrisGame -> TetrisGame
shiftDownFigure curTetrisGame@(Game ff (shiftDown -> fpos) spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = nextFigureGame curTetrisGame
  
-- | Rotates a figure if able to
rotateFigure :: TetrisGame -> TetrisGame
rotateFigure curTetrisGame@(Game (rotate -> ff) fpos spos w h fs grid hrd isPs)
  | goodCoords grid w h (getRealCoords ff fpos) = Game ff fpos spos w h fs grid hrd isPs
  | otherwise = curTetrisGame
  

-- | Checks that the point belongs to the Grid and that it is free.
goodCoords :: Grid -> Int -> Int -> [Block] -> Bool
goodCoords grid w h = all goodCoord
  where
    goodCoord (x,y) = x >= 0 && x < w && y >= 0 && isNothing (Map.lookup (x,y) grid)

getGridAsList :: TetrisGame -> [GridPosition]
getGridAsList (Game _ _ _ _ _ _ grid _ _) = Map.keys grid

shiftRight :: GridPosition -> GridPosition
shiftRight = sumPair (1,0)

shiftLeft :: GridPosition -> GridPosition
shiftLeft = sumPair (-1,0)

shiftDown :: GridPosition -> GridPosition
shiftDown = sumPair (0,-1)