# ---- Constants ----
max_hash_size = 256
hmac_secret = "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=="
count_to_run = 10
requests = 40_000

# ---- Initial datates ----
now = DateTime.utc_now() |> DateTime.to_iso8601()
data = %{
  user_id: 414243,
  role: 11,
  devices: %{
    ios_expired_at: now,
    android_expired_at: now,
    external_api_integration_expired_at: now
  },
  a: String.duplicate("a", 100)
}

# ---- Resize to max_hash_size ----
shrink = fn shrink_fun, d ->
  {:ok, packed} = Msgpax.pack(d, iodata: false)

  cond do
    byte_size(packed) <= max_hash_size -> d
    d.a == "" -> d
    true ->
      new_a = String.slice(d.a, 0, String.length(d.a) - 1)
      shrink_fun.(shrink_fun, %{d | a: new_a})
  end
end

data = shrink.(shrink, data)

# ---- System Information ----
{os_name, _} = :os.type()
IO.puts("OS: #{os_name}")
IO.puts("Elixir version: #{System.version()}")
{:ok, packed} = Msgpax.pack(data, iodata: false)
IO.puts("Hash bytesize: #{byte_size(packed)}")

# ---- Signer для HS256 ----
{:ok, binary_secret} = Base.decode64(hmac_secret)
signer = Joken.Signer.create("HS256", binary_secret)

# ---- Benchmark ----
benchmarks =
  Enum.map(1..count_to_run, fn _ ->
    IO.puts("when creates 40k tokens")

    # ---- Token creation ----
    {create_time, tokens} =
      :timer.tc(fn ->
        Enum.map(1..requests, fn _ ->
          Joken.generate_and_sign!(data, %{}, signer)
        end)
      end)

    IO.puts("#{Float.round(create_time / 1_000_000, 3)} sec")

    # ---- Read tokens ----
    IO.puts("when reads 40k tokens")
    
    {read_time, _} =
      :timer.tc(fn ->
        Enum.each(tokens, fn t ->
          {:ok, _claims} = Joken.verify_and_validate(data, t, signer)
        end)
      end)

    IO.puts("#{Float.round(read_time / 1_000_000, 3)} sec")

    {Float.round(create_time / 1_000_000, 3),
     Float.round(read_time / 1_000_000, 3)}
  end)

create_times = Enum.map(benchmarks, &elem(&1, 0))
read_times   = Enum.map(benchmarks, &elem(&1, 1))

# ---- Statistics ----
stats = fn label, list ->
  sorted = Enum.sort(list)
  mid = div(length(sorted), 2)
  med =
    if rem(length(sorted), 2) == 1 do
      Enum.at(sorted, mid)
    else
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end

  IO.puts("\n#{label}")
  IO.puts("Mediana: #{med}")
  IO.puts("Min: #{Enum.min(sorted)}")
  IO.puts("Max: #{Enum.max(sorted)}")
end

stats.("On Create", create_times)
stats.("On Read",  read_times)
