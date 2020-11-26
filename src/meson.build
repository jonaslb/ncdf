src_dir = meson.current_source_dir()

preprocessor_args = (
    meson.get_compiler('fortran').cmd_array()
    + ['-E', '-P', '-x', 'c', '-I.', '-I@0@'.format(root_dir), '-I./src', '-I@0@'.format(src_dir), '@INPUT0@', '-o', '@OUTPUT@']
)
sedfiltersrc = files(['filter.sed'])[0]
shell_w_vpath = [find_program('env'), 'VPATH=@0@'.format(src_dir)]

inc_files = [
    'netcdf_ncdf_interface_.inc',
    'netcdf_ncdf_funcs_.inc'
]
inc_deps = files(['settings.inc', 'netcdf_ncdf_att_inc.inc', 'netcdf_ncdf_var_inc.inc'])
incfile_src = custom_target(
    'incs',
    command: shell_w_vpath + [find_program('ncdf.sh')],
    depend_files: inc_deps,
    output: inc_files
)
sed_src = custom_target(
    'todo_sed.F90',
    command: preprocessor_args,
    input: files(['netcdf_ncdf_pp.F90']) + incfile_src.to_list(),
    output: 'todo_sed.F90'
)
ncdf_src = custom_target(
    'netcdf_ncdf.F90',
    command: ['sed', '-f', sedfiltersrc, '@INPUT@'],
    capture: true,
    input: sed_src,
    output: 'netcdf_ncdf.F90'
)