src_dir = meson.current_source_dir()

preprocessor_args = (
    meson.get_compiler('fortran').cmd_array()
    + ['-E', '-P', '-x', 'c', '-I.', '-I@0@'.format(root_dir), '-I./src', '-I@0@'.format(src_dir), '@INPUT0@', '-o', '@OUTPUT@']
)
sedfiltersrc = files(['filter.sed'])[0]
shell_w_vpath = [find_program('env'), 'VPATH=@0@'.format(src_dir)]

# Meson does not properly support multiple outputs from configure_file, but we list them here anyway.
# TODO: Use depfile to automatically reconfigure upon change of config.
# We cannot use custom_target because meson needs to scan the fortran files for proper dependency resolution
# at configure time, and custom_target is a build time target. So we must use configure_file to generate
# fortran sources.
inc_files = [
    'netcdf_ncdf_interface_.inc',
    'netcdf_ncdf_funcs_.inc'
]
inc_deps = files(['settings.inc', 'netcdf_ncdf_att_inc.inc', 'netcdf_ncdf_var_inc.inc'])
incfile_src = configure_file(
    command: shell_w_vpath + [find_program('ncdf.sh')],
    output: inc_files[-1]
)
sed_src = configure_file(
    command: preprocessor_args,
    input: files(['netcdf_ncdf_pp.F90']) + [incfile_src],
    output: 'todo_sed.F90'
)
ncdf_src = configure_file(
    command: ['sed', '-f', sedfiltersrc, '@INPUT@'],
    capture: true,
    input: sed_src,
    output: 'netcdf_ncdf.F90'
)
