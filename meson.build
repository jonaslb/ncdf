project('ncdf', 'fortran',
  version : '0.5.1',
  license : 'LGPLv3',
  default_options: ['default_library=static']
)
install = not meson.is_subproject()
add_project_arguments('-DNCDF_4', language: 'fortran')

mpi_dep = dependency('mpi', language: 'fortran', required: get_option('mpi'))
if mpi_dep.found()
  add_project_arguments('-DMPI', language: 'fortran')
endif

libfdict_dep = dependency(
  'fdict',
  fallback: ['fdict', 'fdict_dep']
)
libnetcdf_dep = dependency(
  'netcdf',
  language: 'fortran'
)

root_dir = meson.source_root()
subdir('src')

ncdf_lib = library(
  'ncdf',
  ncdf_src,
  dependencies: [libfdict_dep, libnetcdf_dep],
  install: install
)
ncdf_dep = declare_dependency(link_with: ncdf_lib)
