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
p server.listen(backlog: 5)

client = IO::TCP.ip4(addrinfo: structs.first)
p client
p client.connect(addr: addr)

address, socket, fd, errno = server.accept
puts "ACCEPTED A SOCKET, rc [#{fd}]"
p address, socket, fd, errno
socket.close

IO.popen("netstat -an | grep #{port}") do |io|
  while line = io.gets
    p line
  end
end

p client.close, server.close

sleep 2
puts 'exiting...'
