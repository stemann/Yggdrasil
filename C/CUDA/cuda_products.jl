function cuda_products(cuda_version::VersionNumber;
    cupti_windows_library_name::AbstractString,
    cusolver_version::Union{VersionNumber,Nothing} = nothing,
    nvvm_windows_library_name::AbstractString)
    if (cusolver_version === nothing)
        cusolver_version = cuda_version
    end
    if cuda_version.major == 9 || cuda_version.major == 10 && cuda_version.minor == 0
        cuda_version_lib_extension = "$(cuda_version.major)$(cuda_version.minor)"
        cudart_version_lib_extension = cuda_version_lib_extension
        cufft_version_lib_extension = cuda_version_lib_extension
        cusolver_version_lib_extension = cuda_version_lib_extension
        curand_version_lib_extension = cuda_version_lib_extension
    elseif cuda_version.major == 10 && (cuda_version.minor == 1 || cuda_version.minor == 2)
        cuda_version_lib_extension = "$(cuda_version.major)"
        cudart_version_lib_extension = "$(cuda_version.major)$(cuda_version.minor)"
        cufft_version_lib_extension = cuda_version_lib_extension
        cusolver_version_lib_extension = cuda_version_lib_extension
        curand_version_lib_extension = cuda_version_lib_extension
    else
        cuda_version_lib_extension = "$(cuda_version.major)"
        cudart_version_lib_extension = "110"
        cufft_version_lib_extension = "10"
        cusolver_version_lib_extension = "$(cusolver_version.major)"
        curand_version_lib_extension = "10"
    end
    products = [
        LibraryProduct(["libcudart", "cudart64_$cudart_version_lib_extension"], :libcudart),
        FileProduct(["lib/libcudadevrt.a", "lib/cudadevrt.lib"], :libcudadevrt),
        LibraryProduct(["libcufft", "cufft64_$cufft_version_lib_extension"], :libcufft),
        LibraryProduct(["libcufftw", "cufftw64_$cufft_version_lib_extension"], :libcufftw),
        LibraryProduct(["libcublas", "cublas64_$cuda_version_lib_extension"], :libcublas),
        LibraryProduct(["libnvblas", "nvblas64_$cuda_version_lib_extension"], :libnvblas),
        LibraryProduct(["libcusparse", "cusparse64_$cuda_version_lib_extension"], :libcusparse),
        LibraryProduct(["libcusolver", "cusolver64_$cusolver_version_lib_extension"], :libcusolver),
        LibraryProduct(["libcurand", "curand64_$curand_version_lib_extension"], :libcurand),
        LibraryProduct(["libnppc", "nppc64_$cuda_version_lib_extension"], :libnppc),
        LibraryProduct(["libnppial", "nppial64_$cuda_version_lib_extension"], :libnppial),
        LibraryProduct(["libnppicc", "nppicc64_$cuda_version_lib_extension"], :libnppicc),
        LibraryProduct(["libnppidei", "nppidei64_$cuda_version_lib_extension"], :libnppidei),
        LibraryProduct(["libnppif", "nppif64_$cuda_version_lib_extension"], :libnppif),
        LibraryProduct(["libnppig", "nppig64_$cuda_version_lib_extension"], :libnppig),
        LibraryProduct(["libnppim", "nppim64_$cuda_version_lib_extension"], :libnppim),
        LibraryProduct(["libnppist", "nppist64_$cuda_version_lib_extension"], :libnppist),
        LibraryProduct(["libnppisu", "nppisu64_$cuda_version_lib_extension"], :libnppisu),
        LibraryProduct(["libnppitc", "nppitc64_$cuda_version_lib_extension"], :libnppitc),
        LibraryProduct(["libnpps", "npps64_$cuda_version_lib_extension"], :libnpps),
        LibraryProduct(["libnvvm", nvvm_windows_library_name], :libnvvm),
        FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
        LibraryProduct(["libcupti", cupti_windows_library_name], :libcupti),
        LibraryProduct(["libnvToolsExt", "nvToolsExt64_1"], :libnvtoolsext),
        ExecutableProduct("nvdisasm", :nvdisasm),
    ]
    if cuda_version.major != 10 && cuda_version.minor != 0
        products = vcat(products, [
            LibraryProduct(["libcublasLt", "cublasLt64_$cuda_version_lib_extension"], :libcublasLt),
        ])
    end
    if !((cuda_version.major == 9 && cuda_version.minor == 2)
        || (cuda_version.major == 10 && cuda_version.minor == 0)
        || (cuda_version.major == 10 && cuda_version.minor == 2)) # Excluded cusolverMg in CUDA 10.2 due to aarch64-linux-gnu
        products = vcat(products, [
            LibraryProduct(["libcusolverMg", "cusolverMg64_$cusolver_version_lib_extension"], :libcusolverMg)
        ])
    end
    if cuda_version.major == 9 || cuda_version.major == 10
        products = vcat(products, [
            LibraryProduct(["libnvgraph", "nvgraph64_$cuda_version_lib_extension"], :libnvgraph),
            LibraryProduct(["libnppicom", "nppicom64_$cuda_version_lib_extension"], :libnppicom),
        ])
    elseif cuda_version.major == 11
        products = vcat(products, [
            ExecutableProduct("compute-sanitizer", :compute_sanitizer),
        ])
    end
    return products
end

function cuda_full_products(cuda_version::VersionNumber;
    cupti_windows_library_name::AbstractString,
    cusolver_version::Union{VersionNumber,Nothing} = nothing,
    nvvm_windows_library_name::AbstractString)
    cuda_products_ = cuda_products(cuda_version;
        cupti_windows_library_name,
        cusolver_version,
        nvvm_windows_library_name)
    prefix_cuda = "cuda"
    bin_path = joinpath(prefix_cuda, "bin")
    lib_paths = [joinpath(prefix_cuda, "lib64"), joinpath(prefix_cuda, "lib"), joinpath(prefix_cuda, "bin")]
    products = Product[]
    for product in cuda_products_
        if product isa LibraryProduct
            if product.variable_name == :libcusolverMg && cuda_version.major == 11 && cuda_version.minor >= 5 ## dont_dlopen libcusolverMg on CUDA >= 11.5
                push!(products, LibraryProduct(product.libnames, product.variable_name, lib_paths; dont_dlopen=true))
            elseif product.variable_name == :libnvvm
                push!(products, LibraryProduct(product.libnames, product.variable_name, [joinpath(prefix_cuda, "nvvm/lib64"), joinpath(prefix_cuda, "nvvm/lib"), joinpath(prefix_cuda, "nvvm/bin")]))
            elseif product.variable_name == :libcupti
                push!(products, LibraryProduct(product.libnames, product.variable_name, [joinpath(prefix_cuda, "extras/CUPTI/lib64"), joinpath(prefix_cuda, "extras/CUPTI/lib")]))
            elseif cuda_version.major <= 10 && cuda_version.minor <= 2 ## dont_dlopen on CUDA 9.0-9.2 and on 10.0-10.2
                push!(products, LibraryProduct(product.libnames, product.variable_name, lib_paths; dont_dlopen=true))
            else
                push!(products, LibraryProduct(product.libnames, product.variable_name, lib_paths))
            end
        elseif product isa FileProduct
            if product.variable_name == :libcudadevrt
                paths = String[]
                for p in product.paths
                    if startswith(p, r"lib/lib")
                        push!(paths, joinpath(prefix_cuda, replace(p, r"^lib" => s"lib64")))
                        push!(paths, joinpath(prefix_cuda, p))
                    else
                        push!(paths, joinpath(prefix_cuda, replace(p, r"^lib" => s"lib/x64")))
                    end
                end
                push!(products, FileProduct(paths, product.variable_name))
            elseif product.variable_name == :libdevice
                push!(products, FileProduct([joinpath(prefix_cuda, replace(p, r"^share" => s"nvvm")) for p in product.paths], product.variable_name))
            else
                push!(products, FileProduct([joinpath(prefix_cuda, p) for p in product.paths], product.variable_name))
            end
        elseif product isa ExecutableProduct
            if product.variable_name == :compute_sanitizer
                push!(products, FileProduct([joinpath(bin_path, "compute-sanitizer"), joinpath(prefix_cuda, "compute-sanitizer", "compute-sanitizer.exe")], product.variable_name))
            else
                push!(products, ExecutableProduct(product.binnames, product.variable_name, bin_path))
            end
        end
    end
    products = vcat(products,
        [
            FileProduct(["cuda/include/cub/cub.cuh", "cuda/include/thrust/system/cuda/detail/cub/cub.cuh"], :cuda_include_cub_cub_cuh),
            FileProduct("cuda/include/thrust/version.h", :cuda_include_thrust_version_h),
            FileProduct("cuda/include/cuda.h", :cuda_include_cuda_h),
        ])
    if (cuda_version.major == 10 && cuda_version.minor >= 2) ||
        cuda_version.major >= 11
        push!(products, FileProduct("cuda/include/cuda/std/version", :cuda_include_cuda_std_version))
    end
    return products
end
