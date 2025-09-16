require Logger

CRUD_JT.start(%CRUD_JT.Config{
  encrypted_key: "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=="
})

os = :os.type()

version =
  case os do
    {:unix, :darwin} ->
      {v, 0} = System.cmd("sw_vers", ["-productVersion"])
      String.trim(v)

    {:unix, :linux} ->
      {v, 0} = System.cmd("uname", ["-r"])
      String.trim(v)

    {:win32, _} ->
      {v, 0} = System.cmd("cmd", ["/c", "ver"])
      String.trim(v)

    _ ->
      "unknown"
  end

IO.puts("OS: #{inspect(os)} (#{version})")
arch = :erlang.system_info(:system_architecture) |> to_string()
IO.puts("CPU: #{arch}")
IO.puts("Elixir version: #{System.version()}")

requests = 40_000
count_to_run = 10

data = %{
  user_id: 414243,
  role: 11,
  devices: %{
    ios_expired_at: DateTime.utc_now() |> DateTime.to_string(),
    android_expired_at: DateTime.utc_now() |> DateTime.to_string(),
  },
  a: String.duplicate("a", 100)
}

updated_data = %{user_id: 42, role: 11}

to_sec = fn time_micro -> Float.round(time_micro / 1_000_000, 3) end

results =
  Enum.map(1..count_to_run, fn _ ->
    IO.puts("Checking scale load...")

    # CREATE
    IO.puts("when creates 40k tokens")
    {time, list} =
      :timer.tc(fn ->
        Enum.reduce(1..requests, [], fn _, acc ->
          [CRUD_JT.create(data) | acc]
        end)
      end)

    list = Enum.reverse(list)
    create_sec = to_sec.(time)
    IO.puts("#{create_sec} seconds")

    # READ
    IO.puts("when reads 40k tokens")
    {time, _} = :timer.tc(fn -> Enum.each(list, &CRUD_JT.read/1) end)
    read_sec = to_sec.(time)
    IO.puts("#{read_sec} seconds")

    # UPDATE
    IO.puts("when updates 40k tokens")
    {time, _} = :timer.tc(fn -> Enum.each(list, fn v -> CRUD_JT.update(v, updated_data) end) end)
    update_sec = to_sec.(time)
    IO.puts("#{update_sec} seconds")

    # DELETE
    IO.puts("when deletes 40k tokens")
    {time, _} = :timer.tc(fn -> Enum.each(list, &CRUD_JT.delete/1) end)
    delete_sec = to_sec.(time)
    IO.puts("#{delete_sec} seconds")

    %{create: create_sec, read: read_sec, update: update_sec, delete: delete_sec}
  end)

bench_create = Enum.map(results, & &1.create)
bench_read = Enum.map(results, & &1.read)
bench_update = Enum.map(results, & &1.update)
bench_delete = Enum.map(results, & &1.delete)

median = fn list ->
  sorted = Enum.sort(list)
  Enum.at(sorted, div(length(sorted) - 1, 2))
end

IO.puts("\nOn Create")
IO.puts("Mediana: #{median.(bench_create)}")
IO.puts("Min: #{Enum.min(bench_create)}")
IO.puts("Max: #{Enum.max(bench_create)}")

IO.puts("\nOn Read")
IO.puts("Mediana: #{median.(bench_read)}")
IO.puts("Min: #{Enum.min(bench_read)}")
IO.puts("Max: #{Enum.max(bench_read)}")

IO.puts("\nOn Update")
IO.puts("Mediana: #{median.(bench_update)}")
IO.puts("Min: #{Enum.min(bench_update)}")
IO.puts("Max: #{Enum.max(bench_update)}")

IO.puts("\nOn Delete")
IO.puts("Mediana: #{median.(bench_delete)}")
IO.puts("Min: #{Enum.min(bench_delete)}")
IO.puts("Max: #{Enum.max(bench_delete)}")
