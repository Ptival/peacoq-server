{ mkDerivation, aeson, async, attoparsec, base, bytestring, cereal
, clientsession, configurator, containers, deepseq, directory
, directory-tree, dlist, fetchgit, filepath, Glob, hashable, heist
, http-streams, HUnit, lens, lifted-base, map-syntax, monad-control
, mtl, mwc-random, pwstore-fast, QuickCheck, smallcheck, snap-core
, snap-server, stdenv, stm, syb, test-framework
, test-framework-hunit, test-framework-quickcheck2
, test-framework-smallcheck, text, time, transformers
, transformers-base, unordered-containers, xmlhtml
}:
mkDerivation {
  pname = "snap";
  version = "1.0.0.1";
  src = fetchgit {
    url = "git://github.com/snapframework/snap.git";
    sha256 = "024k06ai4db9rvyzm0wlx7lbxh48r49pz6rrqg4ms7yi6lflclhn";
    rev = "e5d61d2657f33b00bcc8b93cc9442702d515622d";
  };
  libraryHaskellDepends = [
    aeson attoparsec base bytestring cereal clientsession configurator
    containers directory directory-tree dlist filepath hashable heist
    lens lifted-base map-syntax monad-control mtl mwc-random
    pwstore-fast snap-core snap-server stm text time transformers
    transformers-base unordered-containers xmlhtml
  ];
  testHaskellDepends = [
    aeson async attoparsec base bytestring cereal clientsession
    configurator containers deepseq directory directory-tree dlist
    filepath Glob hashable heist http-streams HUnit lens lifted-base
    map-syntax monad-control mtl mwc-random pwstore-fast QuickCheck
    smallcheck snap-core snap-server stm syb test-framework
    test-framework-hunit test-framework-quickcheck2
    test-framework-smallcheck text time transformers transformers-base
    unordered-containers xmlhtml
  ];
  homepage = "http://snapframework.com/";
  description = "Top-level package for the Snap Web Framework";
  license = stdenv.lib.licenses.bsd3;
}
