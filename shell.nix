{ pkgs ? import <nixos-19.03> {} }:
# I couldn't get criterion to build with nixos-19.09 as pkgs, so I explicitly
# specified nixos-19.03 as the default above. If nix-shell doesn't find it:
#
#     nix-channel --add https://nixos.org/channels/nixos-19.03 nixos-19.03
#     nix-channel --update
#     nix-shell
#

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
        optparse-applicative
      ]
    )))
    haskellPackages.cabal-install
    hasklig # nice font
  ];
}
