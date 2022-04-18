default:
  just --choose

reinstall:
  yes | mix archive.uninstall version
  yes | mix archive.install

uninstall:
  yes | mix archive.uninstall version
