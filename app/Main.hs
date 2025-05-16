module Main (main) where

import Text.Pandoc.Definition

main :: IO ()
main = do
  putStrLn ("Here is nullMeta: " ++ show nullMeta)
