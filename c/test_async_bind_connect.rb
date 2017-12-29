$: << '../lib'
require 'io'

port = '3490'
structs = IO::Async::TCP.getv4(hostname: 'localhost', service: port)

p structs.size, structs

server = IO::Async::TCP.ip4(addrinfo: structs.first)
addr = structs.first.sock_addr_ref

p server
p server.bind(addr: addr)
p server.listen(backlog: 5)

client = IO::Async::TCP.ip4(addrinfo: structs.first)
p client
p client.connect(addr: addr)

server.accept do |address, socket, fd, errno|
  puts "ACCEPTED A SOCKET, rc [#{fd}]"
  p address, socket, fd, errno
  socket.close
end

IO.popen("netstat -an | grep #{port}") do |io|
  while line = io.gets
    p line
  end
end

p client.close, server.close

sleep 2
puts 'exiting...'
