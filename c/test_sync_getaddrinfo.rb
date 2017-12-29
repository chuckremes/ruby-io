$: << '../lib'
require 'io'

#structs = IO::Sync::TCP.getallstreams(hostname: nil, service: '22')

#p structs

#structs = IO::Sync::TCP.getv4(hostname: '192.168.1.135', service: '22')
structs = IO::Sync::TCP.getv4(hostname: 'localhost', service: '22')
#structs = IO::Sync::TCP.getv4(hostname: nil, service: '22')

p structs


puts 'setup and running...'

sleep 2
puts 'exiting...'
