$: << '../lib'
require 'io'

IO::Config::Defaults.configure_syscall_mode(mode: :nonblocking)
IO::Config::Defaults.configure_multithread_policy(policy: :silent)

RAND_SLEEP = 10
CLIENT_COUNT = 10

threads = []

port = '3490'
structs = IO::UDP.getv4(hostname: 'localhost', service: port)


server_thread = IO::Internal::Thread.new do
  server = IO::UDP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  rc, errno = server.bind(addr: addr)
  raise "Server could not bind! rc [#{rc}], errno [#{errno}]" if rc < 0
  i = -1

  server_wait = true
  server_sent = 0

  loop do
    addr_buffer, addr_len_buffer = server.class.allocate_addr_buffer
    rc, errno, string, from_addr, from_addr_len = server.recvfrom(buffer: nil, nbytes: 20, flags: 0, addr: addr_buffer, addr_len: addr_len_buffer)
    if rc >= 0
      i += 1
      puts "Server received message: #{string}"

      if string == 'exit'
        server_wait = false
        msg = 'goodbye'
        rc, errno = server.sendto(buffer: msg, nbytes: msg.size, flags: 0, addr: addr_buffer, addr_len: addr_len_buffer.read_int)
        puts "SERVER: breaking out of loop, rc [#{rc}], errno [#{errno}]"
        break
      elsif server_wait
        puts "Server echoing back: #{string}"
        rc, errno = server.sendto(buffer: string, nbytes: string.size, flags: 0, addr: addr_buffer, addr_len: addr_len_buffer.read_int)
        server_sent += 1
        server_wait = false if server_sent >= CLIENT_COUNT - 1
      end
    else
      puts "SERVER: failed on receive."
    end
  end

  puts "finalizing server loop..."
  Thread.current.local[:_scheduler_].finalize_loop
end

completed_count = 0
sleep 0.2

client_thread = IO::Internal::Thread.new do
  clients = []
  times = {}

  start_connects = Time.now
  CLIENT_COUNT.times do |i|
    top = Time.now
    client = IO::UDP.ip4(addrinfo: structs.first)
    addr = structs.first.sock_addr_ref
    times[i] = Time.now
    client.connect(addr: addr) do |sock, rc, errno|
      raise "Client-#{i} failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0

      msg = "echo message: #{i}"
      puts "Client-#{i} sending message: #{msg}"
      client_sent_time = Time.now
      rc, errno = sock.send(buffer: msg, nbytes: msg.size, flags: 0)
      rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
      puts "Client-#{i} received message: #{string}, roundtrip time [#{Time.now - client_sent_time}] seconds"
      completed_count += 1
    end
  end
  puts "[#{Time.now - start_connects}] seconds to issue all #{CLIENT_COUNT} echo sends."
  IO::Timer.sleep(seconds: 1) until completed_count >= CLIENT_COUNT - 1

  client = IO::UDP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  can_exit = false
  client.connect(addr: addr) do |sock, rc, errno|
    raise "Client-last failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
    puts "Last client telling Server to exit..."
    msg = 'exit'
    rc, errno = sock.send(buffer: msg, nbytes: msg.size, flags: 0)
    raise "Client-last failed to send message, rc [#{rc}], errno [#{errno}]" if rc < 0
    completed_count += 1
    rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
    puts "Client-last received: #{string}"
    can_exit = true
    nil
  end

  IO::Timer.sleep(seconds: 1) until can_exit

  puts "finalizing client loop..."
  Thread.current.local[:_scheduler_].finalize_loop
end

# threads << server_thread
threads << client_thread

puts "joining threads..."
threads.each(&:join)

puts 'echo.rb is exiting normally... all threads joined.'
