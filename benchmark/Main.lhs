We aim to benchmark each implementation of Lloyd's algorithm:

> import Prelude hiding (take, zipWith)
> import Algorithms.Lloyd.Sequential (Point(..), Cluster(..), ExpectDivergent(..))
> import Algorithms.Lloyd.Strategies (Partitions(..))
> import qualified Algorithms.Lloyd.Sequential as Sequential (kmeans)
> import qualified Algorithms.Lloyd.Strategies as Strategies (kmeans)
> import Data.List (intercalate)
> import Data.Metric (Metric(..), Euclidean(..))
> import Data.Random.Normal (mkNormals)
> import Data.Vector (Vector, generate, fromList, take, zipWith)
> import Control.Concurrent (getNumCapabilities)
> import Control.Monad (forM)
> import Control.DeepSeq (NFData(..))
> import Criterion.Main (Benchmark, defaultMain, runMode, bgroup, bench, nf, defaultConfig)
> import Criterion.Main.Options (Mode(..), describe)
> import Options.Applicative (execParserPure, defaultPrefs, handleParseResult)
> import System.Environment (getArgs)
> import Text.Read (readMaybe)

> type N = Int
> newtype K = K Int
> instance Show K where
>   show (K k) = show k

Parameters for one single benchmark:

> data Params = Params N K ExpectDivergent

> instance Show Params where
>   show (Params n (K k) (ExpectDivergent e)) =
>     intercalate ", " $ map showParam [ ("n", n), ("k", k), ("max iterations", e) ]

> showParam :: Show v => (String, v) -> String
> showParam (name, value) = name ++ " = " ++ show value

Parameter space for a set of benchmarks:

> data ParamSpace = ParamSpace [N] [K] ExpectDivergent

> singletonSpace :: Params -> ParamSpace
> singletonSpace (Params n k e) = ParamSpace [n] [k] e

> instance Show ParamSpace where
>   show (ParamSpace ns ks (ExpectDivergent e)) = unlines
>     [ "n: " ++ (intercalate ", " $ map show ns)
>     , "k: " ++ (intercalate ", " $ map show ks)
>     , "max iterations: " ++ show e
>     ]

We can create a benchmark or a set of benchmarks:

> type BenchmarkCreator = Params -> Benchmark
> type BenchmarkSetCreator = ParamSpace -> [Benchmark]

We can draw any number of normally distributed 2D points:

> createPoints :: N -> Vector Point
> createPoints count = generate count $ \n -> Point $ fromList [normals !! n, normals !! (n*2)]
>   where normals = mkNormals 0x29a

We can create `k` clusters given at least `k` points:

> createClusters :: K -> Vector Point -> Vector Cluster
> createClusters (K k) points
>   | n < k     = error $ concat [ "Cannot create ", show k, " clusters from ", show n, " points." ]
>   | otherwise = zipWith Cluster (fromList [0..]) ps
>   where
>     ps = take k points
>     n = length ps -- not actual n, but sufficient here

We have default values for the number of points ...

> defaultNs :: [N]
> defaultNs = [2000, 10000]

... and for `k`:

> defaultKs :: [K]
> defaultKs = [K 3, K 10]

We also have a default maximum number of iterations:

> defaultExpDiv :: ExpectDivergent
> defaultExpDiv = ExpectDivergent 10000

So we have a default parameter space:

> defaultParamSpace :: ParamSpace
> defaultParamSpace = ParamSpace defaultNs defaultKs defaultExpDiv

We can list all possible combinations of parameters from a parameter space:

> allCombinations :: ParamSpace -> [Params]
> allCombinations (ParamSpace ns ks e) =
>   with ns as $ \n ->
>     with ks as $ \k ->
>       pure $ Params n k e

To correctly benchmark the result of a pure function, we need to be able to
evaluate it to normal form:

> instance NFData Cluster where
>   rnf (Cluster i c) = rnf i `seq` rnf c
>
> instance NFData Point where
>   rnf (Point v) = rnf v
 
We extract the CLI arguments, use them to construct a benchmark creator
consumer, then apply that consumer to our list of benchmark creators:
 
> main :: IO ()
> main = do
>   t <- getNumCapabilities
>   putStrLn $ "Using " ++ show t ++ " Haskell Execution Context" ++ (if t > 1 then "s" else "")
>   getArgs >>= makeCreatorConsumer >>= ($ benchmarks t)

We can create a list of benchmarks given a number of available threads and a set
of parameters:

> benchmarks :: Int -> BenchmarkSetCreator
> benchmarks threads = map (benchmark threads) . allCombinations

> benchmark :: Int -> BenchmarkCreator
> benchmark threads (Params n k expectDivergent) = bgroup name
>   [ bench "Sequential" $ nf (Sequential.kmeans expectDivergent Euclidean points) clusters
>   , bench "Strategies" $ nf (Strategies.kmeans expectDivergent Euclidean partitions points) clusters
>   ]
>   where
>     name = intercalate "/" [showParam ("n", n), showParam ("k", k)]
>     points = createPoints n
>     clusters = createClusters k points
>     partitions = Partitions threads

We can run benchmarks with the default parameters ...

> withDefaultParams :: BenchmarkSetCreator -> IO ()
> withDefaultParams creator = do
>   mapM_ putStrLn
>     [ "Using default parameters: "
>     , show defaultParamSpace
>     , "Custom parameters syntax:"
>     , "  cabal bench --benchmark-options \"n k max_iterations\""
>     , "Example:"
>     , "  cabal bench --benchmark-options \""++showEx example++" --output report.html +RTS -N2 -H1G -A100M\""
>     , ""
>     ]
>   defaultMain $ creator defaultParamSpace
>   where
>     example = Params 16000 (K 5) (ExpectDivergent 100)
>     showEx (Params n (K k) (ExpectDivergent e)) = intercalate " " $ map show [n, k, e]

... or with custom parameters:

> withCustomParams :: Params -> Mode -> BenchmarkSetCreator -> IO ()
> withCustomParams params mode creator = do
>   putStrLn $ "Using custom parameters: " ++ show params
>   putStrLn $ ""
>   runMode mode $ creator $ singletonSpace params

We have a basic mechanism for parsing command-line arguments: We simply look at
the first arguments; if we can read them, we use them as custom parameters and
hand any additional arguments to Criterion. If we cannot read all of them, we
use the default parameters and leave all arguments for Criterion to handle.

> readMaybeInt :: String -> Maybe Int
> readMaybeInt = readMaybe

> parseParams :: String -> String -> String -> Maybe Params
> parseParams arg_n arg_k arg_e = do
>   n <- readMaybeInt arg_n
>   k <- readMaybeInt arg_k
>   e <- readMaybeInt arg_e
>   return $ Params n (K k) (ExpectDivergent e)

> makeCreatorConsumer :: [String] -> IO (BenchmarkSetCreator -> IO ())
> makeCreatorConsumer args = case args of
>   n : k : e : rest -> do
>     let maybeParams = parseParams n k e
>     let parserResult = execParserPure defaultPrefs (describe defaultConfig) rest
>     mode <- handleParseResult parserResult
>     return $ maybe withDefaultParams (\params -> withCustomParams params mode) maybeParams
>   _ -> return withDefaultParams

These let us express parameter combinations conveniently:

> with :: [p] -> () -> (p -> [Params]) -> [Params]
> with = const . flip concatMap

> as :: ()
> as = ()