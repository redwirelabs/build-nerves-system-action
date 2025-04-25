defmodule Mix.Tasks.Br2.BootstrapEnv do
  @moduledoc """
  Bootstrap environment with the parent project's nerves_system_br version and
  artifact name.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    workspace = System.get_env("GITHUB_WORKSPACE")
    output = System.get_env("GITHUB_OUTPUT")

    mix_script_path = Path.join(workspace, "mix.exs")
    mix_lock_path = Path.join(workspace, "mix.lock")

    with {:missing_mix_lock?, {:ok, mix_lock}} <-
           {:missing_mix_lock?, File.read(mix_lock_path)},
         {:ok, quoted} <- Code.string_to_quoted(mix_lock, [emit_warnings: false]),
         {%{} = lock, _binding} <- Code.eval_quoted(quoted, [], [emit_warnings: false]),
         nerves_system_br <- Map.get(lock, :nerves_system_br),
         {:missing_nerves_system_br?, false} <-
           {:missing_nerves_system_br?, nerves_system_br == nil},
         {:ok, nerves_system_br_version} <- parse_nerves_system_br_version(nerves_system_br),
         {:missing_mix_script?, {:ok, mix_script}} <-
           {:missing_mix_script?, File.read(mix_script_path)},
         {:quote_failed?, {:ok, mix_ast}} <-
           {:quote_failed?, Code.string_to_quoted(mix_script, [emit_warnings: false])},
         {:ok, module_ast} <- parse_module_ast(mix_ast),
         module_ast <- rewrap_project_module(module_ast, workspace),
         {{:module, module, _, _}, _binding} <-
           Code.eval_quoted(module_ast, [], [emit_warnings: false]),
         config <- module.project(),
         {:ok, version} <- File.read(config[:version]) do
        version = String.trim(version)
        sum = checksum(config[:nerves_package][:checksum], workspace)
        artifact_name = "#{config[:app]}-portable-#{version}-#{sum}"

        File.write(output, "artifact_name=#{artifact_name}\n", [:append])
        File.write(output, "nerves_system_br_version=#{nerves_system_br_version}\n", [:append])

      :ok
    else
      {:missing_mix_lock?, {:error, reason}} ->
        Mix.raise("Failed reading mix.lock #{inspect(reason)}")

      {:missing_nerves_system_br?, true} ->
        Mix.raise("Missing required nerves_system_br dependency in mix.lock")

      {:missing_mix_script?, {:error, reason}} ->
        Mix.raise("Failed reading mix.exs #{inspect(reason)}")

      {:quote_failed?, {:error, reason}} ->
        Mix.raise("Unable to generate AST from mix.exs #{inspect(reason)}")

      {:error, reason} ->
        Mix.raise("Failed parsing #{mix_script_path} #{inspect(reason)}")
    end
  end

  defp parse_module_ast(mix_ast) do
    case mix_ast do
      {:defmodule, _, [_, [do: {:__block__, _, module_ast}]]} -> {:ok, module_ast}
      _ -> {:error, :invalid_ast}
    end
  end

  defp rewrap_project_module(module_ast, workspace) do
    module_ast =
      module_ast
      |> Enum.reject(& match?({:use, _, [{_, _, [:Mix, :Project]}]}, &1))
      |> Enum.reject(& match?({:@, _, [{:version, _, _}]}, &1))

    quote do
      defmodule NervesSystem do
        @version unquote(workspace <> "/VERSION")

        unquote(module_ast)
      end
    end
  end

  defp parse_nerves_system_br_version({:hex, _, version, _, _, _, _, _}), do: {:ok, version}
  defp parse_nerves_system_br_version(_), do: {:error, :invalid_lock_format}

  defp expand_paths(paths, dir) do
    paths
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.map(&wildcard_folders/1)
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.uniq()
  end

  defp wildcard_folders(path) do
    case File.dir?(path) do
      true -> Path.join(path, "**")
      _ -> path
    end
  end

  defp checksum(files, project_dir) do
    hashes =
      expand_paths(files, project_dir)
      |> Enum.map(&File.read!/1)
      |> Enum.map(&:crypto.hash(:sha256, &1))

    {checksum, _rest} =
      :crypto.hash(:sha256, hashes)
      |> Base.encode16()
      |> String.split_at(7)

    checksum
  end
end
