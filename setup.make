FC = gfortran
FFLAGS = -O2
INCLUDES := $(shell pkgconf netcdf-fortran --cflags)
LDFLAGS := $(shell pkgconf netcdf-fortran --libs --static)
