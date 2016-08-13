#!/usr/bin/env bash
set -euv

case "$1" in
export)
  echo PATH=/opt/ghc/$GHCVER/bin:/opt/cabal/$CABALVER/bin:$PATH
  ;;
before_install)
  ;;
esac
