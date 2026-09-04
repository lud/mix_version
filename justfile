install: uninstall
  mix do archive.build + archive.install --force

uninstall:
  mix do archive.uninstall mix_version --force

_mix_deps:
  out=$(mix deps.get) && echo "all dependencies fetched" || { echo "$out"; exit 1; }

test:
  mix test

lint:
  mix compile --force --warnings-as-errors
  mix credo

dialyzer:
  mix dialyzer

format:
  mix format --migrate

readmix:
  mix rdmx.update README.md

_libdev_check:
  mix libdev.check

_git_status:
  git status

check: _mix_deps format readmix _libdev_check _git_status
