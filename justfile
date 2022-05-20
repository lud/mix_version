default:
  just --choose

run:
    mix mod.relocate

install: reinstall

reinstall: uninstall
    mix deps.get
    mix archive.install --force

uninstall:
    rm -vf *ez
    mix archive.uninstall mix_version --force

docs:
  rm -rf _build/dev/lib/mix_version
  mix docs

