defmodule MixVersion.Main do
  def main(argv) do
    load_dot_config()
    load_mix_exs()
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
