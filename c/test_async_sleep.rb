$: << '../lib'
require 'io'

start = Time.now
IO::Async::Timer.sleep(seconds: 5)

puts "Slept for [#{Time.now - start}] seconds."
puts Time.now.to_f
