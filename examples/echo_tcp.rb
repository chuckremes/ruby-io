$: << '../lib'
require 'io'

IO::Config::Defaults.configure_syscall_mode(mode: :nonblocking)
Thread.abort_on_exception = true
DEBUG = false
RAND_SLEEP = 10
ClientCount = 10

def tid
  Thread.current.object_id
end

threads = []

port = '3490'
structs = IO::TCP.getv4(hostname: 'localhost', service: port)
Thread.current.local[:name] = 'MAIN' if DEBUG


server_thread = IO::Internal::Thread.new do
  server = IO::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  server.bind(addr: addr)
  server.listen(backlog: 5)
  i = -1

  server_wait = true
  server_accept_time = Time.now
  server_sent = 0

  server.accept do |address, socket, fd, errno|
    if fd > 0
      begin
        i += 1
        rc, errno, string = socket.recv(buffer: nil, nbytes: 20, flags: 0)
        raise "Server failed to receive! rc [#{rc}], errno [#{errno}]" if rc < 0
        puts "Server received message: #{string}"

        if string == 'exit'
          server_wait = false
          rc, errno = socket.send(buffer: 'goodbye', nbytes: 'goodbye'.size, flags: 0)
          raise "Server failed to send exit message!" if rc < 0
          server.accept_break
        elsif server_wait
          timer_reply = IO::Timer.sleep(seconds: rand(RAND_SLEEP))
          puts "Server echoing back: #{string}, #{Time.now.to_f}"
          rc, errno = socket.send(buffer: string, nbytes: string.size, flags: 0)
          raise "Server failed to send echo message: #{string}, rc [#{rc}], errno [#{errno}]" if rc < 0
          server_sent += 1
          server_wait = false if server_sent >= ClientCount - 1
        end
      rescue => e
        STDERR.puts "GOT A SERVER EXCEPTION:  #{e.inspect}"
      end
    else
      STDERR.puts "SERVER: shutting down early, accepted socket failed."
    end
  end

  Thread.current.local[:_scheduler_].finalize_loop
end

completed_count = 0
sleep 0.2

client_thread = IO::Internal::Thread.new do
  clients = []
  times = {}

  start_connects = Time.now
  ClientCount.times do |i|
    top = Time.now
    client = IO::TCP.ip4(addrinfo: structs.first)
    addr = structs.first.sock_addr_ref

    client.connect(addr: addr) do |sock, rc, errno|
      begin
        client_sent_time = Time.now
        fd = sock.instance_variable_get(:@fd)
        raise "Client-#{i} failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0

        msg = "echo message: #{i}"
        puts "Client-#{i} sending message: #{msg}"
        rc, errno = sock.send(buffer: msg, nbytes: msg.size, flags: 0)
        raise "Client-#{i} failed to send! rc [#{rc}], errno [#{errno}]" if rc < 0
        rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
        if string.size < 5
          puts "Client-#{i} got a short response, let's try receiving again, #{Time.now.to_f}"
          rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
          puts "Client-#{i} second echo!"
        end
        raise "received string [#{string.inspect}] is empty! rc [#{rc}], errno [#{errno}]" if string.size < 5
        puts "Client-#{i} received message: #{string}, roundtrip time [#{Time.now - client_sent_time}] seconds"
        completed_count += 1
        IO::Timer.sleep(seconds: 8)
      rescue => e
        STDERR.puts "GOT A CLIENT-#{i} EXCEPTION!: #{e.inspect}"
      end
    end
  end

  IO::Timer.sleep(seconds: 1) until completed_count >= ClientCount

  client = IO::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  can_exit = false
  client.connect(addr: addr) do |sock, rc, errno|
    raise "Client-last failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
    rc, errno = sock.send(buffer: 'exit', nbytes: 'exit'.size, flags: 0)
    raise "Client-last failed to send message, rc [#{rc}], errno [#{errno}]" if rc < 0
    completed_count += 1
    rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
    puts "Client-last received: #{string}"
    can_exit = true
    nil
  end

  IO::Timer.sleep(seconds: 1) until can_exit

  Thread.current.local[:_scheduler_].finalize_loop
end

#threads << server_thread
threads << client_thread

threads.each { |thr| thr.join }

puts 'echo.rb is exiting normally... all threads joined.'
