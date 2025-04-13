# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

const YGGDRASIL_DIR = "../../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))

name = "Faiss_ROCm"
version = v"1.10.0"

include(joinpath(@__DIR__, "..", "common.jl"))

sources = [
    sources...,
    DirectorySource(joinpath(YGGDRASIL_DIR, "H", "HIP", "scripts"); target="HIP_scripts"),
]

# Override the default platforms
platforms = [Platform("x86_64", "linux"; rocm="1")]

# Override the default products
products = [
    products...,
    FileProduct("include/faiss/gpu/GpuIndex.h", :faiss_gpu_gpuindex_h),
    FileProduct("include/faiss/c_api/gpu/GpuIndex_c.h", :faiss_c_api_gpu_gpuindex_c_h),
]

# Build for all supported CUDA toolkits
for platform in platforms
    should_build_platform(triplet(platform)) || continue

    rocm_version = v"5.4.4"
    rocm_deps = [
        Dependency("HIP_jll"),
        BuildDependency(PackageSpec(; name="rocm_cmake_jll", version=rocm_version)),
        BuildDependency(PackageSpec(; name="ROCmCompilerSupport_jll", version=rocm_version)),
        BuildDependency(PackageSpec(; name="ROCmDeviceLibs_jll", version=rocm_version)),
        BuildDependency(PackageSpec(; name="ROCmLLVM_jll", version=rocm_version)),
    ]

    build_tarballs(ARGS, name, version, sources, script, [platform], products, [dependencies; rocm_deps];
                   lazy_artifacts=true,
                   julia_compat="1.9",
                   preferred_gcc_version=v"7",
                   augment_platform_block="""error()""",
                   skip_audit=true,
                   dont_dlopen=true)
end
