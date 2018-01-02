$: << '../lib'
require 'io'

start = Time.now
time = IO::Async::Timer.sleep(seconds: 5)

puts "Slept for [#{Time.now - start}] seconds. [#{time.inspect}]"
puts Time.now.to_f
