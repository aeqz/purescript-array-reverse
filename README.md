# Implementing array reverse in PureScript

Let us say that we want to implement a function to reverse an array in [PureScript](https://www.purescript.org), a strongly typed, purely functional and strictly evaluated programming language that compiles to JavaScript. The type signature for our function would be

```haskell
reverse :: forall a. Array a -> Array a
``` 

and our first and naive attempt could be as follows: while possible, [uncons](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array#v:uncons) the given array into its head and tail and [snoc](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array#v:snoc) the reversed tail and the head.

```haskell
reversePure arr = case uncons arr of
  Nothing -> []
  Just { head, tail } -> snoc (reversePure tail) head
``` 

The implementation is pure (i.e. does not rely on side effects) and recursion is explicit, but it has several problems. The first one is of stack safety: **the function is not tail recursive, so it will crash when given a big array as input**.

We can rearrange the previous implementation to be tail recursive and let the compiler optimize it:

```haskell
reversePureTailRecOpt arr = go arr []
  where
  go arr' acc = case uncons arr' of
    Nothing -> acc
    Just { head, tail } -> go tail (snoc acc head)
``` 

Even if the compiler did not provide such optimization, we could use the [tailrec](https://pursuit.purescript.org/packages/purescript-tailrec/6.1.0) package:

```haskell
reversePureTailRec arr =
  flip tailRec { arr': arr, acc: [] } \{ arr', acc } -> case uncons arr' of
    Nothing -> Done acc
    Just { head, tail } -> Loop { arr': tail, acc: snoc acc head }
``` 

This time, recursion is implicit: **we are defining our function within a general recursion scheme**.

But all these versions have a performance problem due to purity: **every time that uncons and snoc are called, the accumulator array is entirely copied**. We can allow mutability in a controlled manner within the [ST](https://pursuit.purescript.org/packages/purescript-st/6.0.0) monad to create a [new](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array.ST#v:new) array and [push](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array.ST#v:push) the elements of the original array one by one from right to left by mutating the new one:

```haskell
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

``` 

By hiding mutability within our implementation, it seems that we have solved the performance problem, but our first problem shows up again: **our go auxiliary function is not tail recursive, but monadic tail recursive, so this is again not stack safe**. Although this time the compiler cannot automatically optimize it, some monads such as the ST monad have a [MonadRec](https://pursuit.purescript.org/packages/purescript-tailrec/6.1.0/docs/Control.Monad.Rec.Class#t:MonadRec) instance, and we can proceed as before with the tailrec package:

```haskell
reverseSTTailRec arr =
  run do
    ref <- new
    flip tailRecM (length arr - 1) \n -> case arr !! n of
      Nothing -> pure $ Done ref
      Just a -> do
        _ <- push a ref
        pure $ Loop $ n - 1
``` 

We can even use a [utility](https://pursuit.purescript.org/packages/purescript-safely/4.0.0/docs/Control.Safely#v:safely) for MonadRec instances:

```haskell
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
```

And it also plays well with the [fix](https://pursuit.purescript.org/packages/purescript-control/6.0.0/docs/Control.Lazy#v:fix)ed point combinator. Who knows, maybe one day we are working with a programming language that does not allow us to write recursive definitions but provides such a combinator:

```haskell
reverseSTSafelyFix arr =
  run do
    ref <- new
    safely \lift _ ->
      flip fix (length arr - 1) \go n -> case arr !! n of
        Nothing -> pure ref
        Just a -> do
          _ <- lift $ push a ref
          go $ n - 1
```

Finally, although we allowed to mutate the resulting array while the process, maybe it has to be reallocated at some point while it grows. This seems not to be the case in JS Array implementations, but imagine that it could be the case, and we know the size that it has to be in advance, which is the same as the input.

Instead of starting with an empty array, we can [copy](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array.ST#v:withArray) the input array and symmetrically and [unsafely](https://pursuit.purescript.org/packages/purescript-partial/4.0.0/docs/Partial.Unsafe#v:unsafePartial) swap its elements:

```haskell
reverseSTTailRecCopy arr =
  run
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
```

One last thing. We are going to [benchmark](index.js) all these implementations together with the
[reverse](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array#v:reverse) function from [Data.Array](https://pursuit.purescript.org/packages/purescript-arrays/7.1.0/docs/Data.Array), which we have named native:

```sh

npm i          # Install the npm dependencies
npm run bundle # Compile a JS module from our PS sources
npm run bench  # Run our benchmark

Array of 1000 elements benchmark:
    reverseNative x 464,637 ops/sec ±2.25% (89 runs sampled)
    reversePure x 546 ops/sec ±7.51% (89 runs sampled)
    reversePureTailRec x 731 ops/sec ±3.04% (88 runs sampled)
    reversePureTailRecOpt x 788 ops/sec ±1.42% (95 runs sampled)
    reverseST x 14,267 ops/sec ±0.32% (95 runs sampled)
    reverseSTSafely x 2,881 ops/sec ±0.43% (96 runs sampled)
    reverseSTSafelyFix x 2,940 ops/sec ±0.29% (96 runs sampled)
    reverseSTTailRec x 5,728 ops/sec ±0.33% (98 runs sampled)
    reverseSTTailRecCopy x 14,525 ops/sec ±0.19% (96 runs sampled)

Array of 10000 elements benchmark:
    reverseNative x 44,365 ops/sec ±0.69% (94 runs sampled)
    reversePure: 
    reversePureTailRec x 5.59 ops/sec ±1.79% (18 runs sampled)
    reversePureTailRecOpt x 5.51 ops/sec ±1.44% (18 runs sampled)
    reverseST: 
    reverseSTSafely x 265 ops/sec ±0.80% (89 runs sampled)
    reverseSTSafelyFix x 232 ops/sec ±3.40% (80 runs sampled)
    reverseSTTailRec x 561 ops/sec ±0.41% (94 runs sampled)
    reverseSTTailRecCopy x 1,433 ops/sec ±0.46% (95 runs sampled)
```

We can observe the following things:

* The implementations that are not stack safe are crashing in the 10000 elements benchmark.
* The implementation that shows the best performance and is stack safe, apart from the native one, is the one that copies the input array and swaps its elements.
* Despite using mutability side effects and unsafely avoiding runtime array index checking, the [native implementation](https://github.com/purescript/purescript-arrays/blob/v7.1.0/src/Data/Array.js#L195) performance is far away from ours. It uses [JavaScript FFI](https://github.com/purescript/documentation/blob/master/guides/FFI.md) and that is why we are actually naming it native.
