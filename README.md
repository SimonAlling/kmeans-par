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
