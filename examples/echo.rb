$: << '../lib'
require 'io'

Thread.abort_on_exception = true

threads = []

port = '3490'
structs = IO::Async::TCP.getv4(hostname: 'localhost', service: port)

server_thread = Thread.new do
  server = IO::Async::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  server.bind(addr: addr)
  server.listen(backlog: 50)

  server.accept do |address, socket, fd, errno|
    puts "ACCEPTED A SOCKET, rc [#{fd}], errno [#{errno}]"
    if fd > 0
      rc, errno, string = socket.recv(buffer: nil, nbytes: 20, flags: 0)
      puts "SERVER: recv: rc [#{rc}], errno [#{errno}], string [#{string}]"

      puts "SERVER: sending response"
      break if string == 'exit'
      rc, errno = socket.ssend(buffer: string, nbytes: string.size, flags: 0)
      puts "SERVER: ssend: rc [#{rc}], errno [#{errno}]"
      puts "Server: closing socket"
      # +socket+ closes automatically when block exits
      #socket.close
    else
      puts "SERVER: shutting down early, accepted socket failed."
    end
    puts "exiting server block"
  end
end

ClientCount = 10
sleep 1

client_thread = Thread.new do
  clients = []
  ClientCount.times do |i|
    client = IO::Async::TCP.ip4(addrinfo: structs.first)
    addr = structs.first.sock_addr_ref
    puts "CLIENT TRYING TO CONNECT"
    client.connect(addr: addr) do |sock, rc, errno|
      raise "Client-#{i} failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
      
      msg = "echo message: #{i}"
      rc, errno = sock.ssend(buffer: msg, nbytes: msg.size, flags: 0)
      puts "CLIENT: send: rc [#{rc}], errno [#{errno}]"
      rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
      puts "CLIENT: recv: rc [#{rc}], errno [#{errno}], string [#{string}]"
      puts 'client, closing socket'
      
      # +sock+ is automatically closed when block exits
      #sock.close
    end
  end

  client = IO::Async::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  puts "LAST CLIENT TRYING TO CONNECT"
  client.connect(addr: addr) do |sock, rc, errno|
    raise "Client-last failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
    rc, errno = sock.ssend(buffer: 'exit', nbytes: 'exit'.size, flags: 0)
  end
end

threads << server_thread
threads << client_thread

threads.each { |thr| thr.join }