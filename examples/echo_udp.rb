$: << '../lib'
require 'io'

Thread.abort_on_exception = true
DEBUG = false
RAND_SLEEP = 10
ClientCount = 10

def tid
  Thread.current.object_id
end

threads = []

port = '3490'
structs = IO::Async::UDP.getv4(hostname: 'localhost', service: port)
Thread.current.local[:name] = 'MAIN' if DEBUG


server_thread = IO::Internal::Thread.new do
  Thread.current.local[:name] = 'SERVER' if DEBUG
  server = IO::Async::UDP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  rc, errno = server.bind(addr: addr)
  raise "Server could not bind! rc [#{rc}], errno [#{errno}]" if rc < 0
  i = -1

  server_wait = true
  server_sent = 0

  while true
    begin
      addr_buffer, addr_len_buffer = server.class.allocate_addr_buffer
      puts "SERVER: waiting for data..."
      rc, errno, string, from_addr, from_addr_len = server.recvfrom(buffer: nil, nbytes: 20, flags: 0, addr: addr_buffer, addr_len: addr_len_buffer)
      if rc >= 0
        i += 1
        puts "#{tid}, iteration-#{i}, SERVER: recv: rc [#{rc}], errno [#{errno}], string [#{string}], addr_buffer #{addr_buffer.inspect}, len [#{addr_len_buffer.read_uint32}]" if DEBUG
        puts "Server received message: #{string}"

        puts "#{tid}, iteration-#{i}, SERVER: sending response, [#{string}]" if DEBUG

        if string == 'exit'
          server_wait = false
          puts "Server received exit message, server_wait [#{server_wait}]" if DEBUG
          rc, errno = server.sendto(buffer: 'goodbye', nbytes: 'goodbye'.size, flags: 0, addr: addr_buffer, addr_len: addr_len_buffer.read_uint32)
          puts "SERVER: breaking out of loop, rc [#{rc}], errno [#{errno}]"
          break
        elsif server_wait
          #timer_reply = IO::Async::Timer.sleep(seconds: rand(RAND_SLEEP))
          puts "Server echoing back: #{string}"
          rc, errno = server.sendto(buffer: string, nbytes: string.size, flags: 0, addr: addr_buffer, addr_len: addr_len_buffer.read_uint32)
          server_sent += 1
          server_wait = false if server_sent >= ClientCount - 1
          puts "#{tid}, iteration-#{i}, SERVER: send: rc [#{rc}], errno [#{errno}], server_sent [#{server_sent}], server_wait [#{server_wait}]" if DEBUG
          puts "#{tid}, iteration-#{i}, SERVER: closing socket" if DEBUG
          # +socket+ closes automatically when block exits
        end
      else
        puts "SERVER: failed on receive."
      end
    rescue => e
      puts "GOT A SERVER EXCEPTION:  #{e.inspect}"
    end
  end
  puts "#{tid}, iteration-#{i}, exiting [#{i}] server block, server_wait [#{server_wait}]" if DEBUG

  puts "finalizing server loop..."
  Thread.current.local[:_scheduler_].finalize_loop
  puts "#{tid}, server thread exiting..." if DEBUG
end

completed_count = 0
sleep 0.2

client_thread = IO::Internal::Thread.new do
  Thread.current.local[:name] = 'CLIENT' if DEBUG
  clients = []
  times = {}
  puts "Client starting....."

  start_connects = Time.now
  ClientCount.times do |i|
    top = Time.now
    client = IO::Async::UDP.ip4(addrinfo: structs.first)
    addr = structs.first.sock_addr_ref
    puts "#{tid}, CLIENT-#{i}, TRYING TO CONNECT, #{client.inspect}" if DEBUG
    times[i] = Time.now
    client.connect(addr: addr) do |sock, rc, errno|
      begin
        puts "[#{Time.now - times[i]}] seconds to connect client-#{i}" if DEBUG
        client_sent_time = Time.now
        puts "#{tid}, CLIENT-#{i}, INSIDE CONNECT BLOCK, rc [#{rc}], errno [#{errno}], sock [#{sock.inspect}]" if DEBUG
        raise "Client-#{i} failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0

        msg = "echo message: #{i}"
        puts "#{tid}, CLIENT-#{i}: send reply, msg [#{msg}]" if DEBUG
        puts "Client-#{i} sending message: #{msg}"
        rc, errno = sock.send(buffer: msg, nbytes: msg.size, flags: 0)
        puts "#{tid}, CLIENT-#{i}: send: rc [#{rc}], errno [#{errno}]" if DEBUG
        rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
        puts "#{tid}, CLIENT-#{i}: recv: rc [#{rc}], errno [#{errno}], string [#{string}]" if DEBUG
        puts "Client-#{i} received message: #{string}, roundtrip time [#{Time.now - client_sent_time}] seconds"
        puts "#{tid}, CLIENT-#{i}, closing socket" if DEBUG

        # +sock+ is automatically closed when block exits
        #sock.close
        completed_count += 1
      rescue => e
        puts "GOT A CLIENT EXCEPTION!: #{e.inspect}"
      end
    end
    puts "times[#{i}] took: #{Time.now - times[i]} seconds"
  end
  puts "[#{Time.now - start_connects}] seconds to issue all #{ClientCount} echo sends."
  IO::Async::Timer.sleep(seconds: 1) until completed_count >= ClientCount - 1

  client = IO::Async::UDP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  puts "LAST CLIENT TRYING TO CONNECT" if DEBUG
  can_exit = false
  client.connect(addr: addr) do |sock, rc, errno|
    raise "Client-last failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
    puts "Last client telling Server to exit..."
    rc, errno = sock.send(buffer: 'exit', nbytes: 'exit'.size, flags: 0)
    raise "Client-last failed to send message, rc [#{rc}], errno [#{errno}]" if rc < 0
    completed_count += 1
    rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
    puts "Client-last received: #{string}"
    can_exit = true
    nil
  end

  IO::Async::Timer.sleep(seconds: 1) until can_exit

  puts "finalizing client loop..."
  Thread.current.local[:_scheduler_].finalize_loop
  puts "#{tid}, client completed count [#{completed_count}]" if DEBUG
  puts "#{tid}, client thread exiting..." if DEBUG
end

#threads << server_thread
threads << client_thread

puts "joining threads..."
threads.each { |thr| thr.join }
#server_thread.kill

puts 'echo.rb is exiting normally... all threads joined.'
