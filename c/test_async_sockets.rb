$: << '../lib'
require 'io'

port = '3490'
structs = IO::Async::TCP.getv4(hostname: 'localhost', service: port)

p structs.size, structs

server_thr = Thread.new do
  puts "SERVER THREAD"
  server = IO::Async::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  server.bind(addr: addr)
  server.listen(backlog: 5)

  server.accept do |address, socket, fd, errno|
    puts "ACCEPTED A SOCKET, rc [#{fd}], errno [#{errno}]"
    buffer = ::FFI::MemoryPointer.new(:char, 500)
    rc, errno = socket.recv(buffer: buffer, flags: 0)
    puts "SERVER: recv: rc [#{rc}], errno [#{errno}], string [#{buffer.read_string}]"
    p socket
    puts "SERVER: sending response"
    buffer.write_string('response back to client.')
    rc, errno = socket.ssend(buffer: buffer, flags: 0)
    puts "SERVER: recv: rc [#{rc}], errno [#{errno}]"
    puts "Server: closing socket"
    socket.close
  end
end

sleep 1
runflag = true

client_thr = Thread.new do
  puts "CLIENT THREAD"
  client = IO::Async::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  puts "CLIENT TRYING TO CONNECT"
  client.connect(addr: addr)
  puts "CLIENT CONNECTED!"
  buffer = ::FFI::MemoryPointer.new(:char, 500)
  buffer.write_string('request from client to server.')
  puts "CLIENT: about to send some data, [#{buffer.read_string}]"
  rc, errno = client.ssend(buffer: buffer, flags: 0)
  puts "CLIENT: send: rc [#{rc}], errno [#{errno}]"
  rc, errno = client.recv(buffer: buffer, flags: 0)
  puts "CLIENT: recv: rc [#{rc}], errno [#{errno}], string [#{buffer.read_string}]"
  puts 'client, closing socket'
  client.close
  runflag = false
end


sleep 1 while runflag
puts 'runflag is now false'
puts 'exiting...'
