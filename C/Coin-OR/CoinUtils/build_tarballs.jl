include("../coin-or-common.jl")

name = "CoinUtils"
version = CoinUtils_version

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/coin-or/CoinUtils.git", CoinUtils_gitsha),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/CoinUtils*

# Remove misleading libtool files
rm -f ${prefix}/lib/*.la
update_configure_scripts

# Without fixing this configure reports that we can't build shared
# libraries. We use `elf64lppc` for LE support. This seems to be
# fixed on master, but using `update_configure_scripts -reconf` breaks.
sed -i s/elf64ppc/elf64lppc/ configure

mkdir build
cd build/

export CPPFLAGS="${CPPFLAGS} -I${includedir} -I${includedir}/coin"
if [[ ${target} == *mingw* ]]; then
    export LDFLAGS="-L${libdir}"
elif [[ ${target} == *linux* ]]; then
    export LDFLAGS="-ldl -lrt"
fi

../configure \
    --prefix=${prefix} \
    --build=${MACHTYPE} \
    --host=${target} \
    --with-pic \
    --disable-pkg-config \
    --disable-debug \
    --enable-shared \
    lt_cv_deplibs_check_method=pass_all \
    --with-blas --with-blas-lib="-lopenblas" \
    --with-lapack --with-lapack-lib="-lopenblas"

make -j${nproc}
make install
"""

# The products that we will ensure are always built
products = [
    LibraryProduct("libCoinUtils", :libCoinUtils)
]

# Dependencies that must be installed before this package can be built
dependencies = Dependency[
    Dependency("OpenBLAS32_jll", OpenBLAS32_version),
    Dependency("CompilerSupportLibraries_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(
    ARGS,
    name,
    version,
    sources,
    script,
    platforms,
    products,
    dependencies;
    preferred_gcc_version = gcc_version,
    julia_compat = "1.6",
)
