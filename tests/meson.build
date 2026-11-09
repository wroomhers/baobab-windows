# Keep Vala's generated C paths local to this target on Windows as well.
scanner_source = configure_file(
  input: '../src/baobab-scanner.vala',
  output: 'scanner-under-test.vala',
  copy: true,
)

scanner_tests = executable(
  'scanner-tests',
  'scanner.vala',
  scanner_source,
  dependencies: [glib, gio, gobject, gtk],
  install: false,
)

test('scanner', scanner_tests, timeout: 120)
