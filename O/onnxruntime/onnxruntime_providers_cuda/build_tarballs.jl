# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "onnxruntime_providers_cuda"
version = v"1.10.0"

cuda_version = v"11.4"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/microsoft/onnxruntime.git", "0d9030e79888d1d5828730b254fedc53c7b640c1"),
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-gpu-$version.zip", "0da11b8d953fad4ec75f87bb894f72dea511a3940cff2f4dad37451586d1ebbc")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir

if [[ $target == x86_64-w64-mingw32* ]]; then
    dist_name=onnxruntime-win-x64
    chmod 755 $dist_name*/lib/*
    mkdir -p $includedir $libdir
    cp -av $dist_name*/include/* $includedir
    find $dist_name*/lib -not -type d -not -name *tensorrt* | xargs -Isrc cp -av src $libdir
    install_license $dist_name*/LICENSE
else
    export PATH=$prefix/cuda/bin:$PATH

    cd onnxruntime
    python3 tools/ci_build/build.py \
        --build \
        --build_dir $WORKSPACE/srcdir/onnxruntime/build \
        --build_shared_lib \
        --cmake_extra_defines \
            CMAKE_INSTALL_PREFIX=$prefix \
            CMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
            onnxruntime_BUILD_UNIT_TESTS=OFF \
            $cmake_extra_defines \
        --config Release \
        --cuda_home $prefix/cuda \
        --cudnn_home $prefix \
        --use_cuda \
        --parallel $nproc \
        --path_to_protoc_exe $host_bindir/protoc \
        --skip_tests \
        --update
    cd build/Release
    make install
    install_license $WORKSPACE/srcdir/onnxruntime/LICENSE
fi
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "Linux"; cuda = string(cuda_version)),
    Platform("x86_64", "Windows"; cuda = string(cuda_version))
]
platforms = expand_cxxstring_abis(platforms; skip=!Sys.islinux)

# The products that we will ensure are always built
products = [
    LibraryProduct(["libonnxruntime", "onnxruntime"], :libonnxruntime),
    LibraryProduct(["libonnxruntime_providers_shared", "onnxruntime_providers_shared"], :libonnxruntime_providers_shared),
    LibraryProduct(["libonnxruntime_providers_cuda", "onnxruntime_providers_cuda"], :libonnxruntime_providers_cuda; dont_dlopen = true)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("CUDNN_jll", v"8.2.0"),
    Dependency("Zlib_jll"),
    BuildDependency(PackageSpec(name="CUDA_full_jll", version = cuda_version)),
    HostBuildDependency(PackageSpec("protoc_jll", Base.UUID("c7845625-083e-5bbe-8504-b32d602b7110"), v"3.16.1"))
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version = v"8",
    julia_compat = "1.6")
