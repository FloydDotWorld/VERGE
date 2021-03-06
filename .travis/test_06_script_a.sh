#!/usr/bin/env bash
#
# Copyright (c) 2018 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

export LC_ALL=C.UTF-8

TRAVIS_COMMIT_LOG=$(git log --format=fuller -1)
export TRAVIS_COMMIT_LOG

OUTDIR=$BASE_OUTDIR/$TRAVIS_PULL_REQUEST/$TRAVIS_JOB_NUMBER-$HOST
VERGE_CONFIG_ALL="--disable-dependency-tracking --disable-werror --prefix=$TRAVIS_BUILD_DIR/depends/$HOST --bindir=$OUTDIR/bin --libdir=$OUTDIR/lib"

if [ -z "$NO_DEPENDS" ]; then
  DOCKER_EXEC ccache --max-size=$CCACHE_SIZE
fi

if [[ $HOST = *-mingw32 ]]; then
  BEGIN_FOLD docker-build
    DOCKER_EXEC ./.travis/test_06_script_prepare_win.sh
  END_FOLD
else
  BEGIN_FOLD autogen
  if [ -n "$CONFIG_SHELL" ]; then
    DOCKER_EXEC "$CONFIG_SHELL" -c "./autogen.sh"
  else
    DOCKER_EXEC ./autogen.sh
  fi
  END_FOLD

  mkdir build
  cd build || (echo "could not enter build directory"; exit 1)

  BEGIN_FOLD configure
  DOCKER_EXEC ../configure $VERGE_CONFIG_ALL $VERGE_CONFIG || ( cat config.log && false)
  END_FOLD

  BEGIN_FOLD distdir
  DOCKER_EXEC make distdir VERSION=$HOST || ( cat config.log && false)
  END_FOLD

  cd "verge-$HOST" || (echo "could not enter distdir verge-$HOST"; exit 1)

  BEGIN_FOLD copy-helpers
  DOCKER_EXEC cp ../../src/crypto/pow/*_helper.c ./src/crypto/pow
  END_FOLD

  
  BEGIN_FOLD copy-fonts
  DOCKER_EXEC cp -R ../../src/qt/res/fonts ./src/qt/res/fonts/
  END_FOLD

  BEGIN_FOLD configure
  DOCKER_EXEC ./configure $VERGE_CONFIG_ALL $VERGE_CONFIG || ( cat config.log && false)
  END_FOLD

  BEGIN_FOLD build
  DOCKER_EXEC make $MAKEJOBS $GOAL || ( echo "Build failure. Verbose build follows." && DOCKER_EXEC make $GOAL V=1 ; false )
  END_FOLD
fi

cd ${TRAVIS_BUILD_DIR} || (echo "could not enter travis build dir $TRAVIS_BUILD_DIR"; exit 1)