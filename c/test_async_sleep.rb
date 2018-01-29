$: << '../lib'
require 'io'

IO::Config::Defaults.configure_syscall_mode(mode: :nonblocking)

start = Time.now
time = IO::Timer.sleep(seconds: 5)

puts "Slept for [#{Time.now - start}] seconds. [#{time.inspect}]"
puts Time.now.to_f
