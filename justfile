default:
  just --choose

install: reinstall

reinstall:
  yes | mix archive.uninstall mix_version
  yes | mix archive.install

uninstall:
  yes | mix archive.uninstall mix_version

docs:
  rm -rf _build/dev/lib/mix_version
  mix docs
