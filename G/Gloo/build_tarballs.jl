# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "Gloo"
version = v"0.0.20200317"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/facebookincubator/gloo.git", "113bde13035594cafdca247be953610b53026553"),
    DirectorySource("./bundled"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/gloo
atomic_patch -p1 ../patches/mingw32.patch
mkdir build
cd build
if [[ $target != *w64-mingw32* ]]; then
    cmake_extra_args+="-DUSE_LIBUV=ON "
fi
if [[ $bb_full_target == *cuda* ]]; then
    cmake_extra_args+="-DUSE_CUDA=ON -DCUDA_TOOLKIT_ROOT_DIR=$prefix/cuda -DCMAKE_CUDA_FLAGS='-cudart shared' -DCUDA_INCLUDE_DIRS=$prefix/cuda/include -DCUDA_CUDART_LIBRARY=$prefix/lib64/libcudart.so "
    export PATH=$PATH:$prefix/cuda/bin
    export CUDACXX=nvcc
    export CUDAHOSTCXX=$CXX
    apk del cmake
    apk add 'cmake<3.17' --repository=http://dl-cdn.alpinelinux.org/alpine/v3.11/main
fi
cmake \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    $cmake_extra_args \
    ..
cmake --build . -- -j $nproc
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()
filter!(p -> nbits(p) == 64, platforms) # Gloo can only be built on 64-bit systems

cuda_platforms = Platform[]
for cuda_version in [v"10.2"]
    cuda_platform = Platform("x86_64", "linux"; cuda = "$(cuda_version.major).$(cuda_version.minor)")
    push!(platforms, cuda_platform)
    push!(cuda_platforms, cuda_platform)
end

platforms = expand_cxxstring_abis(platforms)
cuda_platforms = expand_cxxstring_abis(cuda_platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libgloo", :libgloo),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency("LibUV_jll"),
    BuildDependency(PackageSpec("CUDA_full_jll", Base.UUID("4f82f1eb-248c-5f56-a42e-99106d144614"), v"10.2.89"); platforms = cuda_platforms),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version=v"5",
    julia_compat="1.6")
