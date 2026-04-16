Mix.path_for(:archives)
|> Path.join("*")
|> Path.wildcard()
|> Enum.any?(&String.contains?(&1, "mix_version"))
|> case do
  true -> raise "mix_version is installed globally, tests will fail"
  false -> :ok
end

ExUnit.start()
