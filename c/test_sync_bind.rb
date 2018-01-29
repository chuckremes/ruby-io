$: << '../lib'
require 'io'

IO::Config::Defaults.configure_syscall_mode(mode: :blocking)

port = '3490'
structs = IO::TCP.getv4(hostname: 'localhost', service: port)

p structs.size, structs

server = IO::TCP.ip4(addrinfo: structs.first)
addr = structs.first.sock_addr_ref

p server
p server.bind(addr: addr)


IO.popen("netstat -an | grep #{port}") do |io|
  while line = io.gets
    p line
  end
end

p server.close

sleep 2
puts 'exiting...'
