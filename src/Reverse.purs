module Reverse where

import Prelude
import Control.Lazy (fix)
import Control.Monad.Rec.Class (Step(..), tailRec, tailRecM)
import Control.Monad.ST as ST
import Control.Safely (safely)
import Data.Array (reverse, length, snoc, uncons, (!!))
import Data.Array.ST (new, push, run, withArray)
import Data.Array.ST.Partial (peek, poke)
import Data.Maybe (Maybe(..))
import Partial.Unsafe (unsafePartial)

reverseNative :: forall a. Array a -> Array a
reverseNative = reverse

reversePure :: forall a. Array a -> Array a
reversePure arr = case uncons arr of
  Nothing -> []
  Just { head, tail } -> snoc (reversePure tail) head

reversePureTailRecOpt :: forall a. Array a -> Array a
reversePureTailRecOpt arr = go arr []
  where
  go arr' acc = case uncons arr' of
    Nothing -> acc
    Just { head, tail } -> go tail (snoc acc head)

reversePureTailRec :: forall a. Array a -> Array a
reversePureTailRec arr =
  flip tailRec { arr': arr, acc: [] } \{ arr', acc } -> case uncons arr' of
    Nothing -> Done acc
    Just { head, tail } -> Loop { arr': tail, acc: snoc acc head }

reverseST :: forall a. Array a -> Array a
reverseST arr =
  run do
    ref <- new
    let
      go n = case arr !! n of
        Nothing -> pure ref
        Just a -> do
          _ <- push a ref
          go $ n - 1
    go $ length arr - 1

reverseSTTailRec :: forall a. Array a -> Array a
reverseSTTailRec arr =
  run do
    ref <- new
    flip tailRecM (length arr - 1) \n -> case arr !! n of
      Nothing -> pure $ Done ref
      Just a -> do
        _ <- push a ref
        pure $ Loop $ n - 1

reverseSTSafely :: forall a. Array a -> Array a
reverseSTSafely arr =
  run do
    ref <- new
    safely \lift _ ->
      let
        go n = case arr !! n of
          Nothing -> pure ref
          Just a -> do
            _ <- lift $ push a ref
            go $ n - 1
      in
        go $ length arr - 1

reverseSTSafelyFix :: forall a. Array a -> Array a
reverseSTSafelyFix arr =
  run do
    ref <- new
    safely \lift _ ->
      flip fix (length arr - 1) \go n -> case arr !! n of
        Nothing -> pure ref
        Just a -> do
          _ <- lift $ push a ref
          go $ n - 1

reverseSTTailRecCopy :: forall a. Array a -> Array a
reverseSTTailRecCopy arr =
  ST.run
    ( flip withArray arr \ref ->
        flip tailRecM { i: 0, j: length arr - 1 } \{ i, j } ->
          if j <= i then
            pure $ Done unit
          else do
            unsafePartial do
              vi <- peek i ref
              vj <- peek j ref
              poke i vj ref
              poke j vi ref
            pure $ Loop { i: i + 1, j: j - 1 }
    )
