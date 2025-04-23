# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

include(joinpath(@__DIR__, "..", "..", "..", "platforms", "microarchitectures.jl"))

name = "Faiss"
version = v"1.9.0"

include(joinpath(@__DIR__, "..", "common.jl"))

platforms = expand_microarchitectures(platforms, ["x86_64", "avx2", "avx512"])

augment_platform_block = """
    $(MicroArchitectures.augment)

    function augment_platform!(platform::Platform)
        # We augment only x86_64
        @static if Sys.ARCH === :x86_64
            augment_microarchitecture!(platform)
        else
            platform
        end
    end
"""

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    augment_platform_block,
    julia_compat="1.9",
    preferred_gcc_version=v"7",
)
