project('asdf', 'd', version : '0.5.5', license: 'BSL-1.0')

description = 'Mir ASDF - JSON Parsing and Serialization'

subprojects = []

has_cpp_headers = false

sources_list = [
    'asdf/asdf',
    'asdf/jsonbuffer',
    'asdf/jsonparser',
    'asdf/outputarray',
    'asdf/package',
    'asdf/serialization',
    'asdf/transform',
    'asdf/utility',
]

sources = []
foreach s : sources_list
    sources += 'source/' + s + '.d'
endforeach

add_project_arguments([
    '-preview=dip1008',
    '-lowmem',
], language: 'd')

required_deps = []

foreach p : subprojects 
    required_deps += dependency(p, fallback : [p, p.underscorify() + '_dep'])
endforeach

directories = ['source']

if has_cpp_headers
    directories += 'include'
endif

directories = include_directories(directories)

this_lib = library(meson.project_name(),
    sources,
    include_directories: directories,
    install: true,
    version: meson.project_version(),
    dependencies: required_deps,
)

this_dep = declare_dependency(
    link_with: [this_lib],
    include_directories: directories,
    dependencies: required_deps,
)

test_versions = []

if has_cpp_headers
    install_subdir('include/',
        strip_directory :true,
        install_dir: 'include/',
    )
endif

install_subdir('source/',
    strip_directory : true,
    install_dir: 'include/d/' + meson.project_name(),
)

import('pkgconfig').generate(this_lib,
    description: description,
    subdirs: 'd/' + meson.project_name(),
)

asdf_dep = this_dep
asdf_lib = this_lib

test_subdirs = []
