{ nixpkgs ? import <nixpkgs> {}, compiler }:
let callPackage = nixpkgs.pkgs.haskell.packages.${compiler}.callPackage; in
let snap = callPackage ./snap.nix { }; in
let peacoq-server = callPackage ./peacoq-server.nix {
  inherit snap;
}; in
nixpkgs.lib.overrideDerivation peacoq-server (old:
  { buildInputs = old.buildInputs ++ (with nixpkgs; [
      haskellPackages.zlib
      zlib
    ]);
    nativeBuildInputs = old.nativeBuildInputs ++ (with nixpkgs; [
      haskellPackages.zlib
      zlib
    ]);
    shellHook = '' export NIXSHELL="$NIXSHELL\[peacoq-server\]" '';
  }
)
