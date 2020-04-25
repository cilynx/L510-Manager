l510_manager_sources = [
  'main.vala',
  'window.vala',
  'filedialog.vala',
  'parameters.vala',
  'dialogs.vala',
  'vfd.vala',
]

vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

l510_manager_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('json-glib-1.0', version: '>=1.4'),
  meson.get_compiler('vala').find_library('posix'),
  dependency('libmodbus'),
]

gnome = import('gnome')

l510_manager_sources += gnome.compile_resources('l510_manager-resources',
  'l510_manager.gresource.xml',
  c_name: 'l510_manager'
)

executable('l510_manager', l510_manager_sources,
  vala_args: '--target-glib=2.50',  dependencies: l510_manager_deps,
  install: true,
)
