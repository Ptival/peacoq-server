#!/usr/bin/env bash
set -euv

CABALPACKAGES="heist io-streams-haproxy snap snap-core snap-server xmlhtml"
SNAP=snap-framework

case "$1" in
clone)
  mkdir -p $SNAP
  cd $SNAP
  for p in ${CABALPACKAGES}; do
    if [ ! -d ${p} ]; then
      git clone https://github.com/Ptival/${p}.git
    fi
  done
  ;;
install)
  cd $SNAP
  for p in ${CABALPACKAGES}; do
    (
    cd ${p}
    # if only there was a way of saying "install if more recent than current"
    cabal install || true
    )
  done
  ;;
esac
