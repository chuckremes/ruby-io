$: << 'lib'
require 'io'

server = Thread.new do
  io = IO::Sync::TCP.open(domain: , type: , protocol: )

  p io
  
  p io.read(nbytes: 4000, offset: 0)
  p io.write(string: 'some string', offset: 3)
  p io.read(nbytes: 4000, offset: 0)
end

client = Thread.new do
  
end

puts 'setup and running...'

sleep 2
puts 'exiting...'