#!/usr/bin/env bash
set -euv

case "$1" in
export)
  echo PATH=$PATH
  ;;
before_install)
  brew update
  brew install cabal-install ghc
  ;;
esac
