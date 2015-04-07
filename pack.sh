#!/bin/bash
[ -z "$PHP_VERSION" ] && PHP_VERSION="5.6.7"
#HOPJOY
CLEAN_INSTALL_DATA=true
CLEAN_INSTALL_DATA_END=false

ZEND_VM="GOTO"

ZLIB_VERSION="1.2.8"
POLARSSL_VERSION="1.3.8"
LIBMCRYPT_VERSION="2.5.8"
GMP_VERSION="6.0.0a"
GMP_VERSION_DIR="6.0.0"
CURL_VERSION="curl-7_39_0"
READLINE_VERSION="6.3"
NCURSES_VERSION="5.9"
PHPNCURSES_VERSION="1.0.2"
PTHREADS_VERSION="2.0.10"
XDEBUG_VERSION="2.2.6"
PHP_POCKETMINE_VERSION="0.0.6"
#UOPZ_VERSION="2.0.4"
WEAKREF_VERSION="0.2.6"
PHPYAML_VERSION="1.1.1"
YAML_VERSION="0.1.6"
#PHPLEVELDB_VERSION="0.1.4"
PHPLEVELDB_VERSION="5e23373bd140bd6492cf38aed0d7ed30a0e734e2"
#LEVELDB_VERSION="1.18"
LEVELDB_VERSION="b633756b51390a9970efde9068f60188ca06a724" #Check MacOS
LIBXML_VERSION="2.9.1"
BCOMPILER_VERSION="1.0.2"
PHPEV_VERSION="0.2.13"
PHPEIO_VERSION="1.2.5"
ZENDOPCACHE_VERSION="7.0.4"
PHPREDIS_VERSION="2.2.7"
# HOPJOY optimize 
march=core2
mtune=core2


echo "[PocketMine] PHP compiler for Linux, MacOS and Android"
DIR="$(pwd)"
DIR_SRC_PKG=${DIR}/pecl
date > "$DIR/install.log" 2>&1
trap "echo \"# \$(eval echo \$BASH_COMMAND)\" >> \"$DIR/install.log\" 2>&1" DEBUG
uname -a >> "$DIR/install.log" 2>&1
echo "[INFO] Checking dependecies"
type make >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"make\""; read -p "Press [Enter] to continue..."; exit 1; }
type autoconf >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"autoconf\""; read -p "Press [Enter] to continue..."; exit 1; }
type automake >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"automake\""; read -p "Press [Enter] to continue..."; exit 1; }
type libtool >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"libtool\""; read -p "Press [Enter] to continue..."; exit 1; }
type m4 >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"m4\""; read -p "Press [Enter] to continue..."; exit 1; }
type wget >> "$DIR/install.log" 2>&1 || type curl >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"wget\" or \"curl\""; read -p "Press [Enter] to continue..."; exit 1; }
type getconf >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"getconf\""; read -p "Press [Enter] to continue..."; exit 1; }
type gzip >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"gzip\""; read -p "Press [Enter] to continue..."; exit 1; }
type bzip2 >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"bzip2\""; read -p "Press [Enter] to continue..."; exit 1; }

#Needed to use aliases
shopt -s expand_aliases
type wget >> "$DIR/install.log" 2>&1
if [ $? -eq 0 ]; then
	alias download_file="wget --no-check-certificate -q -O -"
else
	type curl >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		alias download_file="curl --insecure --silent --location"
	else
		echo "error, curl or wget not found"
	fi
fi

function getfile()
{
	url=$1
	filename=$2
	localfilename=$3
	[ -z "$localfilename" ] && localfilename=$2;

	if [ ! -f ${DIR_SRC_PKG}/${localfilename} ]; then
		echo "download file ${filename}"
		download_file ${url}/${filename} > ${DIR_SRC_PKG}/${localfilename} 
	fi
	cat ${DIR_SRC_PKG}/${localfilename}
}



#if type llvm-gcc >/dev/null 2>&1; then
#	export CC="llvm-gcc"
#	export CXX="llvm-g++"
#	export AR="llvm-ar"
#	export AS="llvm-as"
#	export RANLIB=llvm-ranlib
#else
	export CC="gcc"
	export CXX="g++"
	export RANLIB=ranlib
#fi

COMPILE_FOR_ANDROID=no
HAVE_MYSQLI="--enable-embedded-mysqli --enable-mysqlnd --with-mysqli=mysqlnd"
COMPILE_TARGET=""
COMPILE_CURL="default"
COMPILE_FANCY="no"
HAS_ZEPHIR="false"
IS_CROSSCOMPILE="no"
IS_WINDOWS="no"
DO_OPTIMIZE="yes"
DO_STATIC="no"
COMPILE_DEBUG="no"
COMPILE_LEVELDB="no"
LD_PRELOAD=""

while getopts "::t:oj:srcdlxzff:" OPTION; do

	case $OPTION in
		t)
			echo "[opt] Set target to $OPTARG"
			COMPILE_TARGET="$OPTARG"
			;;
		j)
			echo "[opt] Set make threads to $OPTARG"
			THREADS="$OPTARG"
			;;
		r)
			echo "[opt] Will compile readline and ncurses"
			COMPILE_FANCY="yes"
			;;
		d)
			echo "[opt] Will compile profiler"
			COMPILE_DEBUG="yes"
			;;
		c)
			echo "[opt] Will force compile cURL"
			COMPILE_CURL="yes"
			;;
		x)
			echo "[opt] Doing cross-compile"
			IS_CROSSCOMPILE="yes"
			;;
		l)
			echo "[opt] Will compile with LevelDB support"
			COMPILE_LEVELDB="yes"
			;;
		s)
			echo "[opt] Will compile everything statically"
			DO_STATIC="yes"
			CFLAGS="$CFLAGS -static"
			;;
		z)
			echo "[opt] Will add PocketMine C PHP extension"
			HAS_ZEPHIR="yes"
			;;
		f)
			echo "[opt] Enabling abusive optimizations..."
			DO_OPTIMIZE="yes"
			ffast_math="-fno-math-errno -funsafe-math-optimizations -fno-signed-zeros -fno-trapping-math -ffinite-math-only -fno-rounding-math -fno-signaling-nans" #workaround SQLite3 fail
			CFLAGS="$CFLAGS -O2 -DSQLITE_HAVE_ISNAN $ffast_math -ftree-vectorize -fomit-frame-pointer -funswitch-loops -fivopts"
			if [ "$COMPILE_TARGET" != "mac" ] && [ "$COMPILE_TARGET" != "mac32" ] && [ "$COMPILE_TARGET" != "mac64" ]; then
				CFLAGS="$CFLAGS -funsafe-loop-optimizations -fpredictive-commoning -ftracer -ftree-loop-im -frename-registers -fcx-limited-range"
			fi
			
			if [ "$OPTARG" == "arm" ]; then
				CFLAGS="$CFLAGS -mfloat-abi=softfp -mfpu=vfp"
			elif [ "$OPTARG" == "x86_64" ]; then
				CFLAGS="$CFLAGS -mmmx -msse -msse2 -msse3 -mfpmath=sse -free -msahf -ftree-parallelize-loops=4"
			elif [ "$OPTARG" == "x86" ]; then
				CFLAGS="$CFLAGS -mmmx -msse -msse2 -mfpmath=sse -m128bit-long-double -malign-double -ftree-parallelize-loops=4"
			fi
			;;
		\?)
			echo "Invalid option: -$OPTION$OPTARG" >&2
			exit 1
			;;
	esac
done

# HOPJOY Macos still wrong.
if [ "$(uname -s)" == "Darwin" ]; then
	DO_STATIC="yes"
fi

GMP_ABI=""
TOOLCHAIN_PREFIX=""

if [ "$IS_CROSSCOMPILE" == "yes" ]; then
	export CROSS_COMPILER="$PATH"
	if [[ "$COMPILE_TARGET" == "win" ]] || [[ "$COMPILE_TARGET" == "win32" ]]; then
		TOOLCHAIN_PREFIX="i686-w64-mingw32"
		[ -z "$march" ] && march=i686;
		[ -z "$mtune" ] && mtune=pentium4;
		CFLAGS="$CFLAGS -mconsole"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX --build=$TOOLCHAIN_PREFIX"
		IS_WINDOWS="yes"
		GMP_ABI="32"
		echo "[INFO] Cross-compiling for Windows 32-bit"
	elif [ "$COMPILE_TARGET" == "win64" ]; then
		TOOLCHAIN_PREFIX="x86_64-w64-mingw32"
		[ -z "$march" ] && march=x86_64;
		[ -z "$mtune" ] && mtune=nocona;
		CFLAGS="$CFLAGS -mconsole"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX --build=$TOOLCHAIN_PREFIX"
		IS_WINDOWS="yes"
		GMP_ABI="64"
		echo "[INFO] Cross-compiling for Windows 64-bit"
	elif [ "$COMPILE_TARGET" == "android" ] || [ "$COMPILE_TARGET" == "android-armv6" ]; then
		COMPILE_FOR_ANDROID=yes
		[ -z "$march" ] && march=armv6;
		[ -z "$mtune" ] && mtune=arm1136jf-s;
		TOOLCHAIN_PREFIX="arm-linux-musleabi"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --enable-static-link --disable-ipv6"
		CFLAGS="-static $CFLAGS"
		CXXFLAGS="-static $CXXFLAGS"
		LDFLAGS="-static"
		echo "[INFO] Cross-compiling for Android ARMv6"
	elif [ "$COMPILE_TARGET" == "android-armv7" ]; then
		COMPILE_FOR_ANDROID=yes
		[ -z "$march" ] && march=armv7-a;
		[ -z "$mtune" ] && mtune=cortex-a8;
		TOOLCHAIN_PREFIX="arm-linux-musleabi"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --enable-static-link --disable-ipv6"
		CFLAGS="-static $CFLAGS"
		CXXFLAGS="-static $CXXFLAGS"
		LDFLAGS="-static"
		echo "[INFO] Cross-compiling for Android ARMv7"
	elif [ "$COMPILE_TARGET" == "rpi" ]; then
		TOOLCHAIN_PREFIX="arm-linux-gnueabihf"
		[ -z "$march" ] && march=armv6zk;
		[ -z "$mtune" ] && mtune=arm1176jzf-s;
		if [ "$DO_OPTIMIZE" == "yes" ]; then
			CFLAGS="$CFLAGS -mfloat-abi=hard -mfpu=vfp"
		fi
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX"
		[ -z "$CFLAGS" ] && CFLAGS="-uclibc";
		echo "[INFO] Cross-compiling for Raspberry Pi ARMv6zk hard float"
	elif [ "$COMPILE_TARGET" == "mac" ]; then
		[ -z "$march" ] && march=prescott;
		[ -z "$mtune" ] && mtune=generic;
		CFLAGS="$CFLAGS -fomit-frame-pointer";
		TOOLCHAIN_PREFIX="i686-apple-darwin10"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX"
		#zlib doesn't use the correct ranlib
		RANLIB=$TOOLCHAIN_PREFIX-ranlib
		LEVELDB_VERSION="1bd4a335d620b395b0a587b15804f9b2ab3c403f"
		CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument-hard-error-in-future"
		ARCHFLAGS="-Wno-error=unused-command-line-argument-hard-error-in-future"
		GMP_ABI="32"
		echo "[INFO] Cross-compiling for Intel MacOS"
	elif [ "$COMPILE_TARGET" == "ios" ] || [ "$COMPILE_TARGET" == "ios-armv6" ]; then
		[ -z "$march" ] && march=armv6;
		[ -z "$mtune" ] && mtune=arm1176jzf-s;
		TOOLCHAIN_PREFIX="arm-apple-darwin10"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX -miphoneos-version-min=4.2"
	elif [ "$COMPILE_TARGET" == "ios-armv7" ]; then
		[ -z "$march" ] && march=armv7-a;
		[ -z "$mtune" ] && mtune=cortex-a8;
		TOOLCHAIN_PREFIX="arm-apple-darwin10"
		CONFIGURE_FLAGS="--host=$TOOLCHAIN_PREFIX --target=$TOOLCHAIN_PREFIX -miphoneos-version-min=4.2"
		if [ "$DO_OPTIMIZE" == "yes" ]; then
			CFLAGS="$CFLAGS -mfpu=neon"
		fi
	else
		echo "Please supply a proper platform [android android-armv6 android-armv7 rpi mac ios ios-armv6 ios-armv7 win win32 win64] to cross-compile"
		exit 1
	fi
elif [[ "$COMPILE_TARGET" == "linux" ]] || [[ "$COMPILE_TARGET" == "linux32" ]]; then
	[ -z "$march" ] && march=i686;
	[ -z "$mtune" ] && mtune=pentium4;
	CFLAGS="$CFLAGS -m32";
	GMP_ABI="32"
	echo "[INFO] Compiling for Linux x86"
elif [ "$COMPILE_TARGET" == "linux64" ]; then
	#[ -z "$march" ] && march=x86-64;
	#[ -z "$mtune" ] && mtune=nocona;
	[ -z "$march" ] && march=core2;
	[ -z "$mtune" ] && mtune=core2;

	CFLAGS="$CFLAGS -m64"
	GMP_ABI="64"
	echo "[INFO] Compiling for Linux x86_64"
elif [ "$COMPILE_TARGET" == "rpi" ]; then
	[ -z "$march" ] && march=armv6zk;
	[ -z "$mtune" ] && mtune=arm1176jzf-s;
	CFLAGS="$CFLAGS -mfloat-abi=hard -mfpu=vfp";
	echo "[INFO] Compiling for Raspberry Pi ARMv6zk hard float"
elif [[ "$COMPILE_TARGET" == "mac" ]] || [[ "$COMPILE_TARGET" == "mac32" ]]; then
	[ -z "$march" ] && march=prescott;
	[ -z "$mtune" ] && mtune=generic;
	CFLAGS="$CFLAGS -m32 -arch i386 -fomit-frame-pointer -mmacosx-version-min=10.5";
	if [ "$DO_STATIC" == "no" ]; then
		LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path/../lib";
		export DYLD_LIBRARY_PATH="@loader_path/../lib"
	fi
	LEVELDB_VERSION="1bd4a335d620b395b0a587b15804f9b2ab3c403f"
	CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument-hard-error-in-future"
	ARCHFLAGS="-Wno-error=unused-command-line-argument-hard-error-in-future"
	GMP_ABI="32"
	echo "[INFO] Compiling for Intel MacOS x86"
elif [ "$COMPILE_TARGET" == "mac64" ]; then
	#[ -z "$march" ] && march=core2;
	#[ -z "$mtune" ] && mtune=generic;
	[ -z "$march" ] && march=core2;
	[ -z "$mtune" ] && mtune=core2;
	CFLAGS="$CFLAGS -m64 -arch x86_64 -fomit-frame-pointer -mmacosx-version-min=10.5";
	if [ "$DO_STATIC" == "no" ]; then
		LDFLAGS="$LDFLAGS -Wl,-rpath,@loader_path/../lib";
		export DYLD_LIBRARY_PATH="@loader_path/../lib"
	fi
	LEVELDB_VERSION="1bd4a335d620b395b0a587b15804f9b2ab3c403f"
	CFLAGS="$CFLAGS -Qunused-arguments -Wno-error=unused-command-line-argument-hard-error-in-future"
	ARCHFLAGS="-Wno-error=unused-command-line-argument-hard-error-in-future"
	GMP_ABI="64"
	echo "[INFO] Compiling for Intel MacOS x86_64"
elif [ "$COMPILE_TARGET" == "ios" ]; then
	[ -z "$march" ] && march=armv7-a;
	[ -z "$mtune" ] && mtune=cortex-a8;
	echo "[INFO] Compiling for iOS ARMv7"
elif [ -z "$CFLAGS" ]; then
	if [ `getconf LONG_BIT` == "64" ]; then
		echo "[INFO] Compiling for current machine using 64-bit"
		CFLAGS="-m64 $CFLAGS"
		GMP_ABI="64"
	else
		echo "[INFO] Compiling for current machine using 32-bit"
		CFLAGS="-m32 $CFLAGS"
		GMP_ABI="32"
	fi
fi

if [ "$TOOLCHAIN_PREFIX" != "" ]; then
		export CC="$TOOLCHAIN_PREFIX-gcc"
		export CXX="$TOOLCHAIN_PREFIX-g++"
		export AR="$TOOLCHAIN_PREFIX-ar"
		export RANLIB="$TOOLCHAIN_PREFIX-ranlib"
		export CPP="$TOOLCHAIN_PREFIX-cpp"
		export LD="$TOOLCHAIN_PREFIX-ld"
fi
#
#echo "#include <stdio.h>	\
#int main(int argc,char** argv){ 	\
#	printf("Hello world\n"); 	\
#	return 0; 	\
#}" > test.c

cat << TEST_C_EOF > test.c
	#include <stdio.h>
	int main(int argc,char** argv){
		printf("Hello world\n");
		return 0;
	}
TEST_C_EOF

type $CC >> "$DIR/install.log" 2>&1 || { echo >&2 "[ERROR] Please install \"$CC\""; read -p "Press [Enter] to continue..."; exit 1; }

[ -z "$THREADS" ] && THREADS=1;
[ -z "$march" ] && march=native;
[ -z "$mtune" ] && mtune=native;
[ -z "$CFLAGS" ] && CFLAGS="";

if [ "$DO_STATIC" == "no" ]; then
	[ -z "$LDFLAGS" ] && LDFLAGS="-Wl,-rpath='\$\$ORIGIN/../lib' -Wl,-rpath-link='\$\$ORIGIN/../lib'";
fi

[ -z "$CONFIGURE_FLAGS" ] && CONFIGURE_FLAGS="";

echo "CFLAGS $CFLAGS" >> "$DIR/install.log" 2>&1
if [ "$mtune" != "none" ]; then
	$CC -march=$march -mtune=$mtune $CFLAGS -o test test.c >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		CFLAGS="-march=$march -mtune=$mtune -fno-gcse $CFLAGS"
	fi
else
	$CC -march=$march $CFLAGS -o test test.c >> "$DIR/install.log" 2>&1
	if [ $? -eq 0 ]; then
		CFLAGS="-march=$march -fno-gcse $CFLAGS"
	fi
fi
# HOPJOY
echo "CFLAGS $CFLAGS" >> "$DIR/install.log" 2>&1

function escape_str()
{
	echo $(echo "$1" | sed "s/\//\\\\\//g")
}

if false; then
	pathname=$(escape_str "$DIR/bin/php5")
	for filename in "$DIR/bin/php5/bin/phpize" "$DIR/bin/php5/bin/php-config"; do
		sed -i.backup "s/${pathname}/\\$\\(dirname \$0\\)\\/\\.\\./g" ${filename}
	done
fi
rm -rf "$DIR/bin/php5/share/man"

fname=PHP_${PHP_VERSION}_$(uname -m)_$(uname -s)_$(date +"%Y-%m-%d_%H_%M_%S").tar.gz
tar cvf - bin | gzip > ${fname}
cp ${fname} PHP_${PHP_VERSION}_$(uname -m)_$(uname -s).tar.gz