# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "onnxruntime_providers_cuda"
version = v"1.10.0"

cuda_version = v"11.2.2"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/microsoft/onnxruntime.git", "0d9030e79888d1d5828730b254fedc53c7b640c1"),
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-gpu-$version.zip", "0da11b8d953fad4ec75f87bb894f72dea511a3940cff2f4dad37451586d1ebbc"),
]

# Bash recipe for building across all platforms
script = raw"""
cuda_version=`echo $bb_full_target | sed -E -e 's/.*cuda\+([0-9]+\.[0-9]+).*/\1/'`

cd $WORKSPACE/srcdir

if [[ $target == x86_64-w64-mingw32* ]]; then
    dist_name=onnxruntime-win-x64
    chmod 755 $dist_name*/lib/*
    mkdir -p $includedir $libdir
    cp -av $dist_name*/include/* $includedir
    find $dist_name*/lib -not -type d -not -name *tensorrt* | xargs -Isrc cp -av src $libdir
    install_license $dist_name*/LICENSE
else
    cd onnxruntime
    git submodule update --init --recursive
    mkdir -p build
    cd build
    cmake $WORKSPACE/srcdir/onnxruntime/cmake \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES="50;52;60;61;70;75;80;86" \
        -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared \
        -DCUDA_RUNTIME_LIBRARY=Shared \
        -DCUDA_USE_STATIC_CUDA_RUNTIME=OFF \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DCMAKE_CUDA_COMPILER_ID_RUN=1 \
        -DONNX_CUSTOM_PROTOC_EXECUTABLE=$host_bindir/protoc \
        -Donnxruntime_BUILD_SHARED_LIB=ON \
        -Donnxruntime_BUILD_UNIT_TESTS=OFF \
        -Donnxruntime_DISABLE_RTTI=OFF \
        -Donnxruntime_USE_CUDA=ON \
        -Donnxruntime_CUDA_VERSION=$cuda_version \
        -Donnxruntime_CUDA_HOME=$prefix/cuda \
        -Donnxruntime_CUDNN_HOME=$prefix \
        $cmake_extra_args
    make install
    install_license $WORKSPACE/srcdir/onnxruntime/LICENSE
fi
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "Linux"; cuda = "$(cuda_version.major).$(cuda_version.minor)"),
    Platform("x86_64", "Windows"; cuda = "$(cuda_version.major).$(cuda_version.minor)")
]
platforms = expand_cxxstring_abis(platforms; skip=!Sys.islinux)

# The products that we will ensure are always built
products = [
    LibraryProduct(["libonnxruntime", "onnxruntime"], :libonnxruntime)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("CUDNN_jll", v"8.2.2"),
    Dependency("Zlib_jll"),
    BuildDependency(PackageSpec(name="CUDA_full_jll", version = cuda_version)),
    HostBuildDependency(PackageSpec("protoc_jll", Base.UUID("c7845625-083e-5bbe-8504-b32d602b7110"), v"3.16.1"))
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version = v"8",
    julia_compat = "1.6")
