{ pkgs ? import <nixpkgs> {} }:

with pkgs;

stdenv.mkDerivation {
  name = "kmeans-par";
  buildInputs = [
    (haskell.packages.ghc844.ghcWithPackages (
    ps: with ps; with pkgs.haskell.lib; (
      [
        base
        parallel
        semigroups
        vector

        # Testing and benchmarking
        criterion
        deepseq
        hspec
        normaldistribution
        QuickCheck
        random
      ]
    )))
    haskellPackages.cabal-install
    hasklig # nice font
  ];
}
