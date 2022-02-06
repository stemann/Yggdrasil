# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "onnxruntime_providers_cuda"
version = v"1.10.0"

# Collection of sources required to complete build
sources = [
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-linux-x64-gpu-$version.tgz", "bc880ba8a572acf79d50dcd35ba6dd8e5fb708d03883959ef60efbc15f5cdcb6"),
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-gpu-$version.zip", "0da11b8d953fad4ec75f87bb894f72dea511a3940cff2f4dad37451586d1ebbc")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir

if [[ $target == x86_64-linux-gnu* ]]; then
    dist_name=onnxruntime-linux-x64
elif [[ $target == x86_64-w64-mingw32* ]]; then
    dist_name=onnxruntime-win-x64
    chmod 755 $dist_name*/lib/*
fi
mkdir -p $includedir $libdir
cp -av $dist_name*/include/* $includedir
find $dist_name*/lib -not -type d -not -name *tensorrt* | xargs -Isrc cp -av src $libdir
install_license $dist_name*/LICENSE
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "Linux"; cuda = "11.4"),
    Platform("x86_64", "Windows"; cuda = "11.4")
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
    Dependency("CUDNN_jll", v"8.2.0")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version = v"8",
    julia_compat = "1.6")
