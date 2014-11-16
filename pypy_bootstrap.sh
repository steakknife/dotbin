#!/bin/sh
set -ex

PYPY_PARENT="${PYPY_PARENT:-/opt}"
PYPY_ROOT="${PYPY_ROOT:-$PYPY_ROOT/pypy}"
PYPY_BUILD_RELEASE=${PYPY_BUILD_RELEASE:-1} # 1 for yes, 0 for no
PYPY_RELEASE_VERSION=${PYPY_RELEASE_VERSION:-1.8}
PYPY_BOOTSTRAP_VERSION=${PYPY_BOOTSTRAP_VERSION:-1.8}
PYPY_BOOTSTRAP_LOCATION="${PYPY_BOOTSTRAP_LOCATION:-$PYPY_PARENT/pypy-$PYPY_BOOTSTRAP_VERSION}"
PYPY_WORKSPACE_DIR="${PYPY_WORKSPACE_DIR:-$TMPDIR/pypy-workspace-$PYPY_BOOTSTRAP_VERSION}" # deleted after installation

SUDOPWD=''

_sudo() {
  while [ "x$SUDOPWD" = 'x' ]; do
    read -srp 'Enter your password to sudo:' SUDOPWD >&2
    sleep 1
  done
  echo "$SUDOPWD" | sudo -S $@
}

_sudo id >/dev/null 

if ! which python >/dev/null 2>&1 ; then
  echo 'Python is not installed.  Install it before trying to translate PyPy or it sicut Graecis est ad Latine.'
  false
fi

if ! which cc >/dev/null 2>&1 ; then
  echo 'Are you feeling okay today?  You might want to try translating PyPy with a working compiler first.'
  false
fi

if [ "x$CC" != 'x' ]; then
  if echo "$CC" | egrep -qs '(/|^)gcc-4.2' ; then
    GCC_WARNING=1
  else
    GCC_WARNING=0
  fi
elif readlink "`which cc`" | egrep -qs '(/|^)gcc-4.2' ; then
  GCC_WARNING=1
else
  GCC_WARNING=0
fi

case "$1" in
--force-gcc-4.2)
  CC="`which gcc-4.2`"
  export CC
  GCC="$CC"
  export GCC
  CPP="`which cpp-4.2`"
  export CPP
  CXX="`which c++-4.2`"
  export CXX
  GXX="`which g++-4.2`"
  export GXX
  CXXCPP="$CPP -x c++"
  export CXXCPP

  GCC_WARNING=1
  ;;
--force-llvm)
  CC="`which llvm-gcc`"
  export CC
  GCC="$CC"
  export GCC
  CPP="`which cpp`"
  export CPP
  CXX="`which llvm-g++`"
  export CXX
  GXX="$CXX"
  export GXX
  CXXCPP="$CPP -x c++"
  export CXXCPP

  GCC_WARNING=0
esac

if [ "x$GCC_WARNING" = 'x1' ]; then
  echo 
  echo 'Warning!  GCC 4.2 detected, PyPy compilation may consume ALL available memory and freeze your computer.'
  echo
  echo '          Limiting data usage to 70% of physical memory.'
  PHYS_MEM=`sysctl -a | awk '/^hw\.memsize:/{print$2}'`
  LIMIT=$[PHYS_MEM*7/10]
  ulimit -d $LIMIT 
  echo
  echo '          You may want to Ctrl-C now and choose another compiler.' 
fi 

if [ ! -d "$PYPY_WORKSPACE_DIR" ]; then
  mkdir -p "$PYPY_WORKSPACE_DIR"
fi

pushd "$PYPY_WORKSPACE_DIR" >/dev/null

if [ ! -e "$PYPY_BOOTSTRAP_LOCATION" ]; then
  case "`uname`" in
      Darwin) PYPY_BOOTSTRAP_ARCHITECTURE=osx64 ;;
       Linux) uname -p | grep -qs '64' && PYPY_BOOTSTRAP_ARCHITECTURE=linux64 || PYPY_BOOTSTRAP_ARCHITECTURE=linux ;;
  *win*|*ms*) PYPY_BOOTSTRAP_ARCHITECTURE=win32 ; PYPY_TARBALL_EXT=zip ;;
           *) PYPY_BOOTSTRAP_ARCHITECTURE=''
  esac
  if [ "x$PYPY_BOOTSTRAP_ARCHITECTURE" != 'x' ]; then
    PYPY_BOOTSTRAP_TARBALL="pypy-$PYPY_BOOTSTRAP_VERSION-$PYPY_BOOTSTRAP_ARCHITECTURE.${PYPY_TARBALL_EXT:-tar.bz2}"
    curl -LO https://bitbucket.org/pypy/pypy/downloads/$PYPY_BOOTSTRAP_TARBALL
    echo 'Checksumming PyPy bootstrap tarball.  Aborts on failure.'
    grep -qs `perl -e 'use Digest::SHA qw(sha1_hex); print sha1_hex <>' < $PYPY_BOOTSTRAP_TARBALL ; \
      echo ".*$PYPY_BOOTSTRAP_TARBALL"` << EOF
a6bb7b277d5186385fd09b71ec4e35c9e93b380d  pypy-1.8-linux64.tar.bz2
089f4269a6079da2eabdeabd614f668f56c4121a  pypy-1.8-linux.tar.bz2
15b99f780b9714e3ebd82b2e41577afab232d148  pypy-1.8-osx64.tar.bz2
77a565b1cfa4874a0079c17edd1b458b20e67bfd  pypy-1.8-win32.zip
68554c4cbcc20b03ff56b6a1495a6ecf8f24b23a  pypy-1.7-linux.tar.bz2
d364e3aa0dd5e0e1ad7f1800a0bfa7e87250c8bb  pypy-1.7-linux64.tar.bz2
cedeb1d6bf0431589f62e8c95b71fbfe6c4e7b96  pypy-1.7-osx64.tar.bz2
08463fea89eb0b7797e65d4d13b091174a20fd8d  pypy-1.7-win32.zip
EOF
    tar xf $PYPY_BOOTSTRAP_TARBALL -C "$PYPY_PARENT" || _sudo tar xf $PYPY_BOOTSTRAP_TARBALL -C "$PYPY_PARENT"
    \rm -f $PYPY_BOOTSTRAP_TARBALL
  else
    echo 'PyPy bootstrap binary for this architecture was not found.  Relying on regular python to translate pypy instead.'
  fi
fi

_sudo ln -sf "$PYPY_BOOTSTRAP_LOCATION" /usr/local/bin/pypy

if [ ! -d pypy ]; then
  echo "Downloading pypy source"
  if [ "x$PYPY_BUILD_RELEASE" = 'x1' ]; then
    PYPY_TARBALL=release-${PYPY_RELEASE_VERSION}.tar.bz2
  else
    # builds head of the hg default branch
    PYPY_TARBALL=default.tar.bz2
  fi
  curl -LO https://bitbucket.org/pypy/pypy/get/$PYPY_TARBALL
  if echo $PYPY_TARBALL | grep -qs 'release' ; then
    echo 'Checksumming PyPy tarball.  Aborts on failure.'
    grep -qs `perl -e 'use Digest::SHA qw(sha1_hex); print sha1_hex <>' < $PYPY_TARBALL ; \
      echo ".*$PYPY_TARBALL"` << EOF
4ff684619671d6076879eff88343184d7656c699  release-1.8.tar.bz2
b4be3a8dc69cd838a49382867db3c41864b9e8d9  release-1.7.tar.bz2
EOF
  fi
  tar xf $PYPY_TARBALL
  \mv pypy-pypy-* pypy
  \rm -f $PYPY_TARBALL 
fi

echo 'Sit back and grab some popcorn, "translating" PyPy may take up to 4 hours.  Whatever the fuck that impied.'

cd pypy/pypy/translator/goal
python translate.py --opt=jit targetpypystandalone.py

# TODO: install pypy here
pwd # TODO: <-- remove this whole line
cd -
pwd # TODO: <-- remove this whole line
popd >/dev/null

# \rm -rf "$PYPY_WORKSPACE_DIR" # TODO: uncomment this line after finishing the installation of pypy 
