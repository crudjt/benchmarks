require 'jwt'
require 'msgpack'
require 'benchmark'

MAX_HASH_SIZE = 256
hmac_secret = 'Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=='

COUNT_TO_RUN = 10
REQUESTS = 40_000

data = {user_id: 414243, role: 11, devices: {ios_expired_at: Time.now.to_s, android_expired_at: Time.now.to_s, external_api_integration_expired_at: Time.now.to_s}, a: "a" * 100 }
while MessagePack.pack(data).bytesize > MAX_HASH_SIZE
  data[:a].chop!
end

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

p "Hash bytesize: #{MessagePack.pack(data).bytesize}"

bench_marks_on_create = []
bench_marks_on_read = []

COUNT_TO_RUN.times do
  tokens = []

  p 'Checking scale load...'

  p 'when creates 40k tokens with Turbo Queue'
  bench_on_create =  Benchmark.measure { REQUESTS.times { |i| tokens << JWT.encode(data, hmac_secret, 'HS256') } }
  bench_marks_on_create << bench_on_create.to_a.last.round(3)
  puts bench_on_create

  p 'when reads 40k tokens'
  bench_on_read = Benchmark.measure { REQUESTS.times { |i| JWT.decode(tokens[i], hmac_secret, true, { algorithm: 'HS256' }) } }
  bench_marks_on_read << bench_on_read.to_a.last.round(3)
  puts bench_on_read
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
