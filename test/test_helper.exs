{:ok, _} = Application.ensure_all_started(:briefly)

:ok = MixVersion.Support.Subapp.build_secondary_master!()

# Redirect the CLI output of the whole suite to the calling process. The shell
# is stored in :persistent_term, so it is written once here rather than from
# test setups.
MixVersion.CLI.put_shell(MixVersion.CLI.ProcessShell)

ExUnit.start()
