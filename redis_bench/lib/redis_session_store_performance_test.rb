COUNT_TO_RUN = 10
REQUESTS = 40_000
MAX_HASH_SIZE = 256

os = RbConfig::CONFIG['host_os']
cpu = RbConfig::CONFIG['host_cpu']

version = case os
when /darwin|mac os/
  `sw_vers -productVersion`.strip
when /linux/
  `uname -r`.strip
when /mswin|mingw|cygwin/
  `ver`.strip
else
  "unknown"
end

p "OS: #{os} (#{version})"
p "CPU: #{cpu}"

p "Ruby version: #{RUBY_VERSION}"
p "Rails version: #{Rails.version}"

Rails.application.config.session_store :redis_session_store,
  key: 'your_session_key',
  redis: {
    key_prefix: 'myapp:session:',
    url: 'redis://localhost:6379/0',
  }

# Imitation Rack env
rack_env = {}

# Init RedisSessionStore
store = Rails.application.config.session_store.new(
  Rails.application,
  key: "_redis_bench_session"
)

data = {user_id: 414243, role: 11, devices: {ios_expired_at: Time.now.to_s, android_expired_at: Time.now.to_s, external_api_integration_expired_at: Time.now.to_s}, a: "a" * 100 }
while MessagePack.pack(data).bytesize > MAX_HASH_SIZE
  data[:a].chop!
end

updated_data = { user_id: 42, role: 11 }

p "Hash bytesize: #{MessagePack.pack(data).bytesize}"

bench_marks_on_create = []
bench_marks_on_read = []
bench_marks_on_update = []
bench_marks_on_delete = []

COUNT_TO_RUN.times do
  tokens = []

  p 'Checking scale load...'

  p 'when creates 40k'
  bench_on_create =  Benchmark.measure { REQUESTS.times { |i| tokens << store.send(:set_session, rack_env, store.generate_sid, data, nil) } }
  bench_marks_on_create << bench_on_create.to_a.last.round(3)
  puts bench_on_create

  p 'when reads 40k tokens'
  bench_on_read = Benchmark.measure { REQUESTS.times { |i| store.send(:get_session, rack_env, tokens[i]) } }
  bench_marks_on_read << bench_on_read.to_a.last.round(3)
  puts bench_on_read

  p 'when updates 40k tokens'
  bench_on_update = Benchmark.measure { REQUESTS.times { |i| store.send(:set_session, rack_env, tokens[i], updated_data, nil) } }
  bench_marks_on_update << bench_on_update.to_a.last.round(3)
  puts bench_on_update

  p 'when deletes 40k tokens'
  bench_on_delete = Benchmark.measure { REQUESTS.times { |i| store.send(:destroy_session, rack_env, tokens[i], nil) } }
  bench_marks_on_delete << bench_on_delete.to_a.last.round(3)
  puts bench_on_delete
end

puts

p 'On Create'
p "Mediana: #{bench_marks_on_create[(COUNT_TO_RUN - 1) / 2]}"
p "Min: #{bench_marks_on_create.min}"
p "Max: #{bench_marks_on_create.max}"

puts

p 'On Read'
p "Mediana: #{bench_marks_on_read[(COUNT_TO_RUN - 1) / 2]}"
p "Min: #{bench_marks_on_read.min}"
p "Max: #{bench_marks_on_read.max}"

puts

p 'On Update'
p "Mediana: #{bench_marks_on_update[(COUNT_TO_RUN - 1) / 2]}"
p "Min: #{bench_marks_on_update.min}"
p "Max: #{bench_marks_on_update.max}"

puts

p 'On Delete'
p "Mediana: #{bench_marks_on_delete[(COUNT_TO_RUN - 1) / 2]}"
p "Min: #{bench_marks_on_delete.min}"
p "Max: #{bench_marks_on_delete.max}"
