# Git translates its messages. Force English messages so that assertions on
# command output do not depend on the developer's environment. Only the message
# locale is pinned: setting LC_ALL would also switch the character encoding and
# make the subapp VM run with a latin1 native name encoding.
System.delete_env("LANGUAGE")
System.put_env("LC_MESSAGES", "C")

{:ok, _} = Application.ensure_all_started(:briefly)

:ok = MixVersion.Support.Subapp.build_secondary_master!()

ExUnit.start()
