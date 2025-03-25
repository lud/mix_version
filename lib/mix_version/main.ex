defmodule MixVersion.Main do
  def main(argv) do
    Mix.start()
    load_dot_config()
    load_mix_exs()
    project = Mix.Project.get()
    __MODULE__.module_info()

    Application.loaded_applications() |> dbg(limit: :infinity)
    Mix.Task.run("app.config")
    Application.loaded_applications() |> dbg(limit: :infinity)

    :code.ensure_modules_loaded(Application.spec(:mix_version, :modules))
    {:ok, modules} = :application.get_key(:mix_version, :modules)

    Enum.each(modules, fn mod ->
      Code.ensure_loaded?(mod) |> IO.inspect(limit: :infinity, label: mod)
    end)

    {:ok, modules} = :application.get_key(Mix.Project.get().project()[:app], :modules)

    Enum.each(modules, fn mod ->
      Code.ensure_loaded?(mod) |> IO.inspect(limit: :infinity, label: mod)
    end)

    Mix.Tasks.Version.run(argv)
  end

  defp load_dot_config do
    path = Path.join(Mix.Utils.mix_config(), "config.exs")

    if File.regular?(path) do
      Mix.Tasks.Loadconfig.load_compile(path)
    end
  end

  defp load_mix_exs do
    file = System.get_env("MIX_EXS") || "mix.exs"

    if File.regular?(file) do
      old_undefined = Code.get_compiler_option(:no_warn_undefined)
      Code.put_compiler_option(:no_warn_undefined, :all)
      Code.compile_file(file)
      Code.put_compiler_option(:no_warn_undefined, old_undefined)
    end
  end
end
