$: << '../lib'
require 'io'

IO::Config::Defaults.configure_syscall_mode(mode: :nonblocking)
IO::Config::Defaults.configure_multithread_policy(policy: :silent)
Thread.abort_on_exception = true
RAND_SLEEP = 2
CLIENT_COUNT = 500

def formatted_time
  Time.now.strftime "%Y-%m-%dT%H:%M:%S.%3N"
end

threads = []

port = '3490'
structs = IO::TCP.getv4(hostname: 'localhost', service: port)
Thread.current.extend(IO::Internal::ThreadLocalMixin)

server_thread = IO::Internal::Thread.new do
  server = IO::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref
  server.bind(addr: addr)
  server.listen(backlog: 5)
  i = -1

  server.each_accept do |_address, socket, fd, errno|
    if fd > 0
      i += 1
      rc, errno, string = socket.recv(buffer: nil, nbytes: 20, flags: 0)
      raise "Server failed to receive! rc [#{rc}], errno [#{errno}]" if rc < 0

      puts "[#{formatted_time}] Server received message: #{string}"

      if string == 'exit'
        reply = 'goodbye'
        rc, errno = socket.send(buffer: reply, nbytes: reply.size, flags: 0)
        raise "Server failed to send exit message!" if rc < 0

      else
        sec = rand(RAND_SLEEP)
        #puts "[#{formatted_time}] Server will randomly sleep [#{sec}] seconds before echoing, #{string}"
        timer_reply = IO::Timer.sleep(seconds: sec)

        puts "[#{formatted_time}] Server echoing back: #{string}"
        rc, errno = socket.send(buffer: string, nbytes: string.size, flags: 0)
        raise "Server failed to send echo message: #{string}, rc [#{rc}], errno [#{errno}]" if rc < 0
      end
    else
      STDERR.puts "SERVER: shutting down early, accepted socket failed."
    end
  end

  IO::Timer.sleep(seconds: nil) # sleep forever
end

completed_count = 0
sleep 0.2 # give server thread a chance to spin up otherwise first connect will raise

CLIENT_COUNT.times do |i|
  client = IO::TCP.ip4(addrinfo: structs.first)
  addr = structs.first.sock_addr_ref

  client.connect(addr: addr) do |sock, rc, errno|
    raise "Client-#{i} failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0

    msg = "echo message: #{i}"
    puts "[#{formatted_time}] Client-#{i}, sending message: #{msg}"
    rc, errno = sock.send(buffer: msg, nbytes: msg.size, flags: 0)
    raise "Client-#{i} failed to send! rc [#{rc}], errno [#{errno}]" if rc < 0

    rc, errno, string = sock.recv(buffer: nil, nbytes: 20, flags: 0)
    raise "received string [#{string.inspect}] is empty! rc [#{rc}], errno [#{errno}]" if string.size < 5

    puts "[#{formatted_time}] Client-#{i} received message: #{string}"
    completed_count += 1
  end
end

IO::Timer.sleep(seconds: 1) until completed_count >= CLIENT_COUNT

client = IO::TCP.ip4(addrinfo: structs.first)
addr = structs.first.sock_addr_ref
can_exit = false
client.connect(addr: addr) do |sock, rc, errno|
  raise "Client-last failed to connect, rc [#{rc}], errno [#{errno}]" if rc < 0
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

Thread.current.local[:_scheduler_].finalize_loop

puts 'echo.rb is exiting normally... all clients responded.'
