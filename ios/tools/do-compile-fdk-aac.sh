#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script is based on projects below

#--------------------
echo "===================="
echo "[*] check host"
echo "===================="
set -e


FF_XCRUN_DEVELOPER=`xcode-select -print-path`
if [ ! -d "$FF_XCRUN_DEVELOPER" ]; then
  echo "xcode path is not set correctly $FF_XCRUN_DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case $FF_XCRUN_DEVELOPER in
     *\ * )
           echo "Your Xcode path contains whitespaces, which is not supported."
           exit 1
          ;;
esac


#--------------------
# include


#--------------------
# common defines
FF_ARCH=$1
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm64, i386, x86_64, ...'.\n"
    exit 1
fi


FF_BUILD_ROOT=`pwd`
FF_TAGET_OS="darwin"


# fdk-aac build params
export COMMON_FF_CFG_FLAGS=

AAC_CFG_FLAGS=
AAC_EXTRA_CFLAGS=
AAC_CFG_CPU=

# i386, x86_64
AAC_CFG_FLAGS_SIMULATOR=

# armv7, armv7s, arm64
AAC_CFG_FLAGS_ARM=
AAC_CFG_FLAGS_ARM="--host=arm-apple-darwin"

echo "build_root: $FF_BUILD_ROOT"

#--------------------
echo "===================="
echo "[*] config arch $FF_ARCH"
echo "===================="

FF_BUILD_NAME="unknown"
FF_XCRUN_PLATFORM="iPhoneOS"
FF_XCRUN_OSVERSION=
FF_GASPP_EXPORT=

if [ "$FF_ARCH" = "i386" ]; then
    FF_BUILD_NAME="fdk-aac-i386"
    FF_XCRUN_PLATFORM="iPhoneSimulator"
    FF_XCRUN_OSVERSION="-mios-simulator-version-min=6.0"
    AAC_CFG_FLAGS_ARM="--host=i386-apple-darwin"
    AAC_CFG_FLAGS="$AAC_CFG_FLAGS_ARM $AAC_CFG_FLAGS"
elif [ "$FF_ARCH" = "x86_64" ]; then
    FF_BUILD_NAME="fdk-aac-x86_64"
    FF_XCRUN_PLATFORM="iPhoneSimulator"
    FF_XCRUN_OSVERSION="-mios-simulator-version-min=7.0"
    AAC_CFG_FLAGS_ARM="--host=x86_64-apple-darwin"
    AAC_CFG_FLAGS="$AAC_CFG_FLAGS_ARM $AAC_CFG_FLAGS"
elif [ "$FF_ARCH" = "arm64" ]; then
    FF_BUILD_NAME="fdk-aac-arm64"
    FF_XCRUN_OSVERSION="-fembed-bitcode"
    AAC_CFG_FLAGS_ARM="--host=aarch64-apple-darwin"
    AAC_CFG_FLAGS="$AAC_CFG_FLAGS_ARM $AAC_CFG_FLAGS"
    FF_GASPP_EXPORT="GASPP_FIX_XCODE5=1"

else
    echo "unknown architecture $FF_ARCH";
    exit 1
fi

echo "build_name: $FF_BUILD_NAME"
echo "platform:   $FF_XCRUN_PLATFORM"
echo "osversion:  $FF_XCRUN_OSVERSION"

#--------------------
echo "===================="
echo "[*] make ios toolchain $FF_BUILD_NAME"
echo "===================="


FF_BUILD_SOURCE="$FF_BUILD_ROOT/$FF_BUILD_NAME"
FF_BUILD_PREFIX="$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output"

mkdir -p $FF_BUILD_PREFIX


FF_XCRUN_SDK=`echo $FF_XCRUN_PLATFORM | tr '[:upper:]' '[:lower:]'`
FF_XCRUN_SDK_PLATFORM_PATH=`xcrun -sdk $FF_XCRUN_SDK --show-sdk-platform-path`
FF_XCRUN_SDK_PATH=`xcrun -sdk $FF_XCRUN_SDK --show-sdk-path`
FF_XCRUN_CC="xcrun -sdk $FF_XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future"
FF_XCRUN_AS="$FF_BUILD_SOURCE/extras/gas-preprocessor.pl $FF_XCRUN_CC"

export CROSS_TOP="$FF_XCRUN_SDK_PLATFORM_PATH/Developer"
export CROSS_SDK=`echo ${FF_XCRUN_SDK_PATH/#$CROSS_TOP\/SDKs\//}`
export BUILD_TOOL="$FF_XCRUN_DEVELOPER"
export CC="$FF_XCRUN_CC -arch $FF_ARCH $FF_XCRUN_OSVERSION"
export CXX="$CC"
export CPP="$CC -E"
export AS="$FF_XCRUN_AS"

echo "build_source: $FF_BUILD_SOURCE"
echo "build_prefix: $FF_BUILD_PREFIX"
echo "CROSS_TOP: $CROSS_TOP"
echo "CROSS_SDK: $CROSS_SDK"
echo "BUILD_TOOL: $BUILD_TOOL"
echo "CC: $CC"
echo "CXX: $CXX"
echo "CPP: $CPP"
echo "AS: $AS"

#--------------------
echo "\n--------------------"
echo "[*] configurate fdk-aac"
echo "--------------------"

AAC_CFG_FLAGS="$AAC_CFG_FLAGS --prefix=$FF_BUILD_PREFIX"

# xcode configuration
export DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

cd $FF_BUILD_SOURCE
if [ -f "./Makefile" ]; then
    echo 'reuse configure'
elif [ -f "./configure" ]; then
    echo 'already run autogen.sh'
    echo "config: $AAC_CFG_FLAGS"
    ./Configure \
        $AAC_CFG_FLAGS
    make clean
else
    echo 'should run autogen.sh first'
    ./autogen.sh

    echo "config: $AAC_CFG_FLAGS"
    ./Configure \
        $AAC_CFG_FLAGS
    make clean
fi

#--------------------
echo "\n--------------------"
echo "[*] compile fdk-aac"
echo "--------------------"
set +e
make
make install
