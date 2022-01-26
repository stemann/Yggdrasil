# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "rr"
version = v"5.5"

# Collection of sources required to build rr
sources = [
    GitSource("https://github.com/Keno/rr.git",
              "2bf0e4aa88b70b09d3ae0f32b5607a0bd785545d")
]

# Bash recipe for building across all platforms
script = raw"""
pip3 install pexpect
cd ${WORKSPACE}/srcdir/rr/

mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${prefix} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
      -Ddisable32bit=ON -DBUILD_TESTS=ON -DWILL_RUN_TESTS=ON -Dstaticlibs=ON ..
make -j${nproc}

# WIP
# Run the rr test suite
ctest --output-on-failure -j${nproc}

make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
# rr only supports Linux
platforms = [
    Platform("x86_64", "linux", libc="glibc"),
]
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    ExecutableProduct("rr", :rr),
]

# Dependencies that must be installed before this package can be built
# This is really a build dependency
dependencies = [
    BuildDependency("capnproto_jll"),
    Dependency("CompilerSupportLibraries_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies,
               preferred_gcc_version=v"8")
