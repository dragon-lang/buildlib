# TODO: should probably use a specific channel
{ nixpkgs ? import <nixpkgs> {}
, profile
}:

with nixpkgs;

let
  custom_pkgs = import ./nixpkgs/custom-packages.nix {};
  common_pkgs = [gdb gcc glibc binutils coreutils debianutils git gnumake custom_pkgs.rund];
in

mkShell {
  buildInputs = if profile == "dmd-build" then
    common_pkgs ++ [dmd]
  else if profile == "ldc-build" then
    common_pkgs ++ [ldc]
  else if profile == "dmd-test" then
    common_pkgs ++ [dmd]
  else
    throw "unknown profile '${profile}', expected 'dmd-build' or 'ldc-build'";
}

