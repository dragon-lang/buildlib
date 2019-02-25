{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };
in
rec {
  rund = import ./pkgs/rund {
    inherit (pkgs) stdenv fetchFromGitHub dmd ldc;
  };
}
