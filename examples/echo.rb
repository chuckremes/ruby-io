$: << '../lib'
require 'io'

Thread.abort_on_exception = true
DEBUG = false

threads = []

port = '3490'
structs = IO::Async::TCP.getv4(hostname: 'localhost', service: port)
Thread.current.local[:name] = 'MAIN' if DEBUG


server_thread = IO::Internal::Thread.new do
  Thread.current.local[:name] = 'SERVER' if DEBUG
  server = IO::Async::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  server.bind(addr: addr)
  server.listen(backlog: 50)
  i = -1

  server.accept do |address, socket, fd, errno|
    if fd > 0
      i += 1
      puts "#{tid}, iteration-#{i}, ACCEPTED A SOCKET, rc [#{fd}], errno [#{errno}]" if DEBUG
      rc, errno, string = socket.recv(buffer: nil, nbytes: 20, flags: 0)
      puts "#{tid}, iteration-#{i}, SERVER: recv: rc [#{rc}], errno [#{errno}], string [#{string}]" if DEBUG
      puts "Server received message: #{string}"

      puts "#{tid}, iteration-#{i}, SERVER: sending response, [#{string}]" if DEBUG
      break if string == 'exit'
      puts "Server echoing back: #{string}"
      rc, errno = socket.ssend(buffer: string, nbytes: string.size, flags: 0)
      puts "#{tid}, iteration-#{i}, SERVER: ssend: rc [#{rc}], errno [#{errno}]" if DEBUG
      puts "#{tid}, iteration-#{i}, SERVER: closing socket" if DEBUG
      # +socket+ closes automatically when block exits
      #socket.close
    else
      puts "SERVER: shutting down early, accepted socket failed."
    end
    puts "#{tid}, iteration-#{i}, exiting [#{i}] server block" if DEBUG
  end
  Thread.current.local[:_scheduler_].finalize_loop
  puts "#{tid}, server thread exiting..." if DEBUG
end

ClientCount = 10
completed_count = 0
sleep 1

client_thread = IO::Internal::Thread.new do
  Thread.current.local[:name] = 'CLIENT' if DEBUG
  clients = []
  ClientCount.times do |i|
    client = IO::Async::TCP.ip4(addrinfo: structs.first)
    addr = structs.first.sock_addr_ref
    puts "#{tid}, CLIENT-#{i}, TRYING TO CONNECT" if DEBUG
    client.connect(addr: addr) do |sock, rc, errno|
      puts "#{tid}, CLIENT-#{i}, INSIDE CONNECT BLOCK, rc [#{rc}], errno [#{errno}], sock [#{sock.inspect}]" if DEBUG
      raise "Client-#{i} failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0

      msg = "echo message: #{i}"
      puts "#{tid}, CLIENT-#{i}: ssend reply, msg [#{msg}]" if DEBUG
      puts "Client-#{i} sending message: #{msg}"
      rc, errno = sock.ssend(buffer: msg, nbytes: msg.size, flags: 0)
      puts "#{tid}, CLIENT-#{i}: ssend: rc [#{rc}], errno [#{errno}]" if DEBUG
      timer_reply = IO::Async::Timer.sleep(seconds: rand(4))
      puts "#{tid}, CLIENT-#{i}, timer reply #{timer_reply.inspect}" if DEBUG
      rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
      puts "#{tid}, CLIENT-#{i}: recv: rc [#{rc}], errno [#{errno}], string [#{string}]" if DEBUG
      puts "Client-#{i} received message: #{string}"
      puts "#{tid}, CLIENT-#{i}, closing socket" if DEBUG

      # +sock+ is automatically closed when block exits
      #sock.close
      completed_count += 1
    end
  end

  client = IO::Async::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  puts "LAST CLIENT TRYING TO CONNECT" if DEBUG
  client.connect(addr: addr) do |sock, rc, errno|
    raise "Client-last failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
    puts "Last client telling Server to exit..."
    rc, errno = sock.ssend(buffer: 'exit', nbytes: 'exit'.size, flags: 0)
    completed_count += 1
  end

  IO::Async::Timer.sleep(seconds: 1) until completed_count >= ClientCount
  Thread.current.local[:_scheduler_].finalize_loop
  puts "#{tid}, client completed count [#{completed_count}]" if DEBUG
  puts "#{tid}, client thread exiting..." if DEBUG
end

threads << server_thread
threads << client_thread

threads.each { |thr| thr.join }

puts 'echo.rb is exiting normally... all threads joined.'
