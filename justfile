default:
  just --choose

run:
    mix mod.relocate

install: reinstall

reinstall: uninstall
    mix deps.get --only prod
    MIX_ENV=prod mix compile --force
    MIX_ENV=prod mix escript.build
    MIX_ENV=prod mix escript.install _build/escript/xvsn --force

uninstall:
    mix escript.uninstall xvsn --force

docs:
  rm -rf _build/dev/lib/mix_version
  mix docs

