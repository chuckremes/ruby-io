$: << '../lib'
require 'io'

start = Time.now

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
    if fd >= 0
      buffer = ::FFI::MemoryPointer.new(:char, 500)
      rc, errno = socket.recv(nbytes: buffer.size, buffer: buffer, flags: 0)
      puts "SERVER: recv: rc [#{rc}], errno [#{errno}], string [#{buffer.read_string}]"
      p socket
      puts "SERVER: sending response"
      buffer.write_string('response back to client.')
      rc, errno = socket.send(buffer: buffer, nbytes: buffer.size, flags: 0)
      puts "SERVER: recv: rc [#{rc}], errno [#{errno}]"
      puts "Server: closing socket"
      socket.close
    else
      puts "SERVER: shutting down early, accepted socket failed."
    end
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
  rc, errno = client.send(buffer: buffer, nbytes: buffer.size, flags: 0)
  puts "CLIENT: send: rc [#{rc}], errno [#{errno}]"
  rc, errno = client.recv(nbytes: buffer.size, buffer: buffer, flags: 0)
  puts "CLIENT: recv: rc [#{rc}], errno [#{errno}], string [#{buffer.read_string}]"
  puts 'client, closing socket'
  client.close
  runflag = false
end


sleep 0.01 while runflag
puts 'runflag is now false'
puts "done after [#{Time.now - start}] seconds"
puts 'exiting...'
