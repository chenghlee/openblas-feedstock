#!/bin/bash

# See this workaround
# ( https://github.com/xianyi/OpenBLAS/issues/818#issuecomment-207365134 ).
CF="${CFLAGS}"
unset CFLAGS

if [[ `uname` == 'Darwin' ]]; then
     export LIBRARY_SEARCH_VAR=DYLD_FALLBACK_LIBRARY_PATH
else
     export LIBRARY_SEARCH_VAR=LD_LIBRARY_PATH
fi
eval export ${LIBRARY_SEARCH_VAR}="${PREFIX}/lib"

# Build all CPU targets and allow dynamic configuration
# Build LAPACK.
# Enable threading. This can be controlled to a certain number by
# setting OPENBLAS_NUM_THREADS before loading the library.
make QUIET_MAKE=1 DYNAMIC_ARCH=1 BINARY=${ARCH} NO_LAPACK=0 NO_AFFINITY=1 USE_THREAD=1 CFLAGS="${CF}" FFLAGS="-frecursive"
# Fix paths to ensure they have the $PREFIX in them.
if [[ `uname` == 'Darwin' ]]; then
    for OPENBLAS_LIB in $( find "${PREFIX}/lib" -name "libopenblas*.dylib" ); do
        install_name_tool -change \
                @rpath/./libgfortran.3.dylib \
                "${PREFIX}/lib/libgfortran.3.dylib" \
                "${OPENBLAS_LIB}"
        install_name_tool -change \
                @rpath/./libquadmath.0.dylib \
                "${PREFIX}/lib/libquadmath.0.dylib" \
                "${OPENBLAS_LIB}"
        install_name_tool -change \
                @rpath/./libgcc_s.1.dylib \
                "${PREFIX}/lib/libgcc_s.1.dylib" \
                "${OPENBLAS_LIB}"
    done
fi
OPENBLAS_NUM_THREADS=$CPU_COUNT make test
make install PREFIX="${PREFIX}"

# As OpenBLAS, now will have all symbols that BLAS, CBLAS or LAPACK have,
# create libraries with the standard names that are linked back to
# OpenBLAS. This will make it easier for packages that are looking for them.
for arg in blas cblas lapack; do
    ln -fs $PREFIX/lib/pkgconfig/openblas.pc $PREFIX/lib/pkgconfig/$arg.pc
    ln -fs $PREFIX/lib/libopenblas.a $PREFIX/lib/lib$arg.a
    ln -fs $PREFIX/lib/libopenblas$SHLIB_EXT $PREFIX/lib/lib$arg$SHLIB_EXT
done

if [[ `uname` == 'Darwin' ]]; then
    # Needs to fix the install name of the dylib so that the downstream projects will link
    # to libopenblas.0.dylib instead of libopenblasp-r0.2.20.dylib
    # In linux, SONAME is libopenblas.so.0 instead of libopenblasp-r0.2.20.so, so no change needed
    if [[ -f ${PREFIX}/lib/libopenblas.0.dylib ]]; then
        install_name_tool -id ${PREFIX}/lib/libopenblas.0.dylib ${PREFIX}/lib/libopenblas.0.dylib;
    else
        exit 1;
    fi
fi

