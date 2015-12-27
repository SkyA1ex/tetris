module Drawing (drawWindow) where

import Config
import Figures
import World
import Util

import Control.Monad.State
import Control.Monad.Reader

import Graphics.Gloss
import Graphics.Gloss.Interface.Pure.Game

-- DRAWING FUNCTIONS

-- | Draws all debug components
drawDebug :: StateT TetrisGame (Reader AppConfig) Picture
drawDebug = do
  state <- get
  return $ drawHelp
  where
    drawHelp = translate (-250) 270 $ scale 0.2 0.2 $ text "Press P to pause or unpause the game."

-- | Draws a one basic block on the grid
drawBlock :: Block -> StateT TetrisGame (Reader AppConfig) Picture
drawBlock block = do
  conf <- ask
  let cp = cupPosition conf
  let sz = blockSize conf
  let bxp = fst cp + ((fromIntegral $ fst block) * sz)
  let byp = snd cp + ((fromIntegral $ snd block) * sz)
  return $ Color (makeColorI 30 30 30 255) (lineLoop [ (bxp + 1, byp + 1)
                                                     , (bxp + sz - 1, byp + 1)
                                                     , (bxp + sz - 1, byp + sz - 1)
                                                     , (bxp + 1, byp + sz - 1) ] )

-- | Draws falling figure of the game state
drawFigure :: GridPosition -> Figure -> StateT TetrisGame (Reader AppConfig) Picture
drawFigure p f@(Figure _ _ bs) = mapM drawBlock (getRealCoords f p) >>= return . Pictures

-- | Draws a figure on the grid
drawGrid :: StateT TetrisGame (Reader AppConfig) Picture
drawGrid = do
  state <- get
  pics <- mapM drawBlock (getGridAsList state)
  return $ Pictures pics

-- | Draws a cup figures are falling into (with empty grid)
drawCup :: StateT TetrisGame (Reader AppConfig) Picture
drawCup = do
  config <- ask
  (x, y) <- fmap cupPosition $ ask
  sz <- fmap cupSize $ ask
  let height = snd sz
  let width = fst sz
  return $ Pictures [drawEmptyGrid config, Line [ (x, y + height)
                                                , (x, y)
                                                , (x + width, y)
                                                , (x + width, y + height) ] ]

-- | Draws empty grid
drawEmptyGrid :: AppConfig -> Picture
drawEmptyGrid conf =
  let cp = cupPosition conf in
  let gsY = snd $ gridSize conf in  -- Number of cells along vertical axis
  let stepY = (snd $ cupSize conf) / fromIntegral gsY in  -- step y along vertical axis
  let gsX = fst $ gridSize conf in  -- Number of cells along horizontal axis
  let stepX = (fst $ cupSize conf) / fromIntegral gsX in  -- step x along horizontal axis
  Color (makeColorI 200 200 200 255) $ Pictures [drawHorizontal cp gsY stepY, drawVertical cp gsX stepX]
    where
      drawHorizontal cp gsY stepY =
        let points = [snd cp + stepY * 1, snd cp + stepY * 2 .. snd cp + stepY * (fromIntegral gsY - 1)] in -- Y line coords along vertical axis
        Pictures $ zipWith (\p1 p2 -> Line [(fst cp, p1), (fst cp + (fst $ cupSize conf), p2)]) points points
      drawVertical cp gsX stepX =
        let points = [fst cp + stepX * 1, fst cp + stepX * 2 .. fst cp + (stepX * fromIntegral gsX - 1)] in -- X line coords along horizontal axis
        Pictures $ zipWith (\p1 p2 -> Line [(p1, snd cp), (p2, snd cp + (snd $ cupSize conf))]) points points

-- | Draws right sidebar
drawSidebar :: StateT TetrisGame (Reader AppConfig) Picture
drawSidebar = do
  state <- get
  conf <- ask
  pic <- drawNextFigure (gridSize conf) (head $ nextFigures state) (blockSize conf) (cupPosition conf)
  return $ Pictures [pic]
  where
    drawNextFigure pos fig bs cp = 
      let np = (fst pos + 2, snd pos - 4) in 
      drawFigure np fig >>= return 
        . Pictures 
        . ( : [ translate (fst cp + (fromIntegral $ fst np) * bs) (snd cp + (fromIntegral $ (snd np + 3)) * bs) $ scale 0.15 0.15 $ text "Prepare for this" ] )

-- | Draws the left game window
drawGame :: StateT TetrisGame (Reader AppConfig) Picture
drawGame = do
  cupPic <- drawCup
  (x, y) <- fmap gamePosition $ ask
  return $ Pictures [ cupPic ]

-- | Draws the whole window picture
drawWindow :: StateT TetrisGame (Reader AppConfig) Picture
drawWindow = do
  gamePic <- drawGame
  state <- get
  let pos = fallingPosition state
  let fig = fallingFigure state
  figurePic <- drawFigure pos fig
  sidebarPic <- drawSidebar
  debugPic <- drawDebug
  gridPic <- drawGrid
  return $ Pictures [ gridPic, gamePic, figurePic, sidebarPic, debugPic ]