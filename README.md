![CI](https://travis-ci.org/fmap/kmeans.png)

Sequential and parallel implementations of Lloyd's algorithm for k-means clustering, adapted from Marlow's _Parallel and Concurrent Programming in Haskell_.

## Developer documentation

### Getting started

You need GHC and Cabal.
If you're on NixOS, you should just need to clone the repo and run `nix-shell` in its root.
Otherwise, this worked for me on a fresh Ubuntu Server 18.04 LTS installation:

```shell
# Install GHC and Cabal:
sudo add-apt-repository -y ppa:hvr/ghc
sudo apt update
sudo apt install -y cabal-install-2.2 ghc-8.4.4
PATH=/opt/ghc/bin:$PATH
# Install kmeans-par and dependencies:
git clone https://github.com/SimonAlling/kmeans-par
cd kmeans-par
cabal update
cabal install --enable-benchmarks
cabal configure --enable-benchmarks
```

### Running the benchmarks

    cabal bench

Note that this will use as many threads as can be simultaneously executed on the machine, e.g. four threads on a dual-core CPU with SMT.
In most cases you'll get better or much better performance by setting the number of threads equal to the number of _physical cores_, for example

    cabal bench --benckmark-options "+RTS -N2"

if you have a dual-core CPU.

**NB:** GHC 8.0.2 (part of the Haskell Platform as of 2019-04-14) did not work for me.
The benchmark just kept running until it was killed with an out-of-memory error.

#### Custom parameters

You can provide any values you like for _n_, _k_ and the max number of iterations, respectively:

    cabal bench --benchmark-options "16000 20 999"

You can provide arguments to Criterion and [runtime system options](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/runtime_control.html) as well:

    cabal bench --benchmark-options "16000 20 999 --output report.html +RTS -N2 -H1G -A100M -RTS"

Explanation:

  * `--output report.html`: Criterion will render nice interactive charts to `report.html`.
  * `+RTS ... -RTS`: Options for the Haskell runtime system.
  * `-N2`: Use 2 Haskell Execution Contexts (threads).
  * `-H1G`: 1 GB heap size.
  * `-A100M`: 100 MB allocation area size (for garbage collection).


## Version 2

During my master's thesis, I, Simon Alling, made several improvements to this package, described in this chapter.
I wrote it before I became a maintainer of the package, and before I knew about [the original repo](https://github.com/fmap/kmeans).

### Linear instead of quadratic complexity

_Credit goes to John Hughes for discovering this._

The sequential implementation in v1 is quadratic in the number of points; in v2 it's instead linear.

The parallel implementation splits the set of points into smaller chunks, so it isn't as heavily impacted by the quadratic behavior.
This gave rise to inflated parallelism figures, for example a 7× speedup on 4 threads.

Notably, the inner loop in v1 is O(_n² / k_) if it loops over _n_ points, so the overall complexity is improved as _k_ is increased. (In the sequential implementation, _n_ is the total number of points; in the parallel one, it's the number of points per partition.)
In practice, the most dramatic difference between v1 and v2 is seen when _k_ = 2.

For example, I benchmarked the sequential implementation with _k_ = 2 before and after this change:

| Problem size [points]: | 1k | 2k |  4k |  8k |  16k |
|-----------------------:|---:|---:|----:|----:|-----:|
|           Before [ms]: | 14 | 53 | 119 | 548 | 5252 |
|            After [ms]: | 10 | 29 |  50 | 117 |  267 |

### Different semantics of the `partitions` parameter

From [the source code](https://hackage.haskell.org/package/kmeans-par-1.5.1/docs/src/Algorithms-Lloyd-Strategies.html) of v1:

> This version of k-means takes an additional arguments -- the number of partitions the set of points'll be divided into. This needn't equal the number of processors: […]

However, the actual implementation in v1 is such that `partitions` is the number of points in each partition, not the number of partitions.
One consequence of this is the surprising fact that on a _p_-core CPU, _p_ is _not_ a good choice for `partitions`; instead, _n_ / _p_ is a good choice for _n_ points.

v2 implements `partitions` as the number of partitions instead.

### Improved benchmark suite

v2 makes it easier to run benchmarks with custom problem sizes, number of clusters and maximum number of iterations.

It also uses larger numbers for the default benchmarks, to produce more reliable and representative results.

### Doesn't depend on `metric`

I couldn't install the original package on any of my machines (with Cabal 1.24/2.0/2.2, GHC 8.0.2/8.2.2/8.4.4), because the `metric` package wouldn't build:

    src/Data/Packed/Matrix/Extras.hs:5:1: error:
        Could not find module ‘Data.Packed.Matrix’
        Use -v to see a list of the files searched for.
      |
    5 | import Data.Packed.Matrix (Matrix(..), fromLists, trans)
      | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

v2 re-implements the (very few) necessary parts of `metric` _ad hoc_.
It may not be optimal, but it works for the benchmarks at least.

Because I couldn't build with `metric` as a dependency, this package exports a `Data.Metric` module which contains only the necessary parts mentioned above.
Hopefully, we will be able to use `metric` instead in the future.

### Some smaller modifications

I have added the `feager-blackholing` flag, added a `shell.nix` file etc.
