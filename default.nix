{ nixpkgs ? import <nixpkgs> {}
, compiler ? "ghc802"
}:
let peacoqtop = (import ../peacoqtop/default.nix { inherit nixpkgs compiler; }); in
let callPackage = nixpkgs.pkgs.haskell.packages.${compiler}.callPackage; in 
let snap = callPackage ./snap.nix; in
let peacoq-server = callPackage ./peacoq-server.nix {
  inherit peacoqtop;
  inherit snap;
}; in
nixpkgs.lib.overrideDerivation peacoqtop (old:
  { buildInputs = old.buildInputs ++ (with nixpkgs; [
      haskellPackages.zlib
      zlib
      # doesn't need anything?
    ]);
    nativeBuildInputs = old.nativeBuildInputs ++ (with nixpkgs; [
      haskellPackages.zlib
      zlib
    ]);
    shellHook = '' export NIXSHELL="$NIXSHELL\[peacoq-server\]" '';
  }
)

