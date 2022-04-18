default:
  just --choose

reinstall:
  yes | mix archive.uninstall mix_version
  yes | mix archive.install

uninstall:
  yes | mix archive.uninstall mix_version
