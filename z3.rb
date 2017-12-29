$: << 'lib'
require 'io'

      flags = IO::Config::Flags.new
      io = IO::Sync::File.open(path: '/tmp/t', flags: flags.create.readwrite)

      p io
      
      p io.read(nbytes: 4000, offset: 0)
      p io.write(string: 'some string', offset: 3)
      p io.read(nbytes: 4000, offset: 0)

sleep 1

p io.close

puts "exiting..."

