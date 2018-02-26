require 'io/internal/states/socket/closed'
require 'io/internal/states/socket/bound'
require 'io/internal/states/socket/connected'
require 'io/internal/states/socket/open'

class IO
  class TCP
    class << self
      def open(domain:, type:, protocol:, timeout: nil)
        Config::Defaults.syscall_backend.setup
        result = Config::Defaults.syscall_backend.socket(domain: domain, type: type, protocol: protocol, timeout: timeout)

        raise "failed to allocate socket" if result[:rc] < 0

        if POSIX::PF_INET == domain
          TCP4.new(fd: result[:rc])
        elsif POSIX::PF_INET6 == domain
          TCP6.new(fd: result[:rc])
        else
          # Temporary raise... should respect the set Policy. If socket
          # failed to open, return a TCP socket in the Closed state.
          # TCP.new(fd: nil, state: :closed)
          raise "Unknown Protocol Family [#{domain}] for TCP socket!"
        end
      end

      def ip4(addrinfo:, timeout: nil)
        open(
          domain: addrinfo[:ai_family],
          type: addrinfo[:ai_socktype],
          protocol: addrinfo[:ai_protocol],
          timeout: timeout
        )
      end

      def getallstreams(hostname:, service:, timeout: nil)
        hints = POSIX::AddrInfoStruct.new
        hints[:ai_flags] = POSIX::AI_PASSIVE
        hints[:ai_family] = POSIX::AF_UNSPEC
        hints[:ai_socktype] = POSIX::SOCK_STREAM

        getaddrinfo(hostname: hostname, service: service, hints: hints, timeout: timeout)
      end

      def getv4(hostname:, service:, flags: nil, timeout: nil)
        # FIXME: add a Config::Socket::AddressInfoFlag class to handle ai_flags
        hints = POSIX::AddrInfoStruct.new
        hints[:ai_flags] = POSIX::AI_PASSIVE
        hints[:ai_family] = POSIX::PF_INET
        hints[:ai_socktype] = POSIX::SOCK_STREAM

        getaddrinfo(hostname: hostname, service: service, hints: hints, timeout: timeout)
      end

      def getaddrinfo(hostname:, service:, hints:, timeout: nil)
        Config::Defaults.syscall_backend.setup
        results = ::FFI::MemoryPointer.new(:pointer)
        result = Config::Defaults.syscall_backend.getaddrinfo(
          hostname: hostname,
          service: service,
          hints: hints,
          results: results,
          timeout: timeout
        )
        ptr = results.read_pointer
        structs = []

        return structs if result[:rc] < 0 || ptr.nil?

        loop do
          # We don't own the memory containing the addrinfo structs, so we need to copy
          # these to our own memory
          addrinfo = POSIX::AddrInfoStruct.new(ptr)

          if addrinfo[:ai_family] == POSIX::AF_INET
            POSIX::SockAddrInStruct.new(addrinfo[:ai_addr])
          else
            POSIX::SockAddrIn6Struct.new(addrinfo[:ai_addr])
          end

          structs << POSIX::AddrInfoStruct.copy_to_new(addrinfo)

          ptr = addrinfo[:ai_next]
          break if ptr.nil? || ptr.null?
        end
        structs
      end
    end

    def initialize(fd:, state: :open, error_policy: nil)
      @creator = Thread.current
      reply = FCNTL.set_nonblocking(fd: fd) # ignore return code?

      @context = if state == :open
                   Internal::States::Socket::Open.new(
                     fd: fd,
                     backend: Config::Defaults.syscall_backend,
                     parent: self
                   )
                 elsif state == :connected
                   Internal::States::Socket::Connected.new(
                     fd: fd,
                     backend: Config::Defaults.syscall_backend
                   )
                 else
                   Internal::States::Socket::Closed.new(
                     fd: -1,
                     backend: Config::Defaults.syscall_backend
                   )
                 end
    end

    def close(timeout: nil)
      safe_delegation do |context|
        rc, errno, behavior = context.close(timeout: timeout)
        [rc, errno]
      end
    end

    def bind(addr:, timeout: nil)
      safe_delegation do |context|
        rc, errno, behavior = context.bind(addr: addr, timeout: timeout)
        update_context(behavior)
        [rc, errno]
      end
    end

    def connect(addr:, timeout: nil, &blk)
      rc, errno = safe_delegation do |context|
        rc, errno, behavior = context.connect(addr: addr, timeout: timeout)
        update_context(behavior)
        [rc, errno]
      end
      if block_given?
        block = make_connect_block(self, rc, errno, &blk)

        # mark current fiber as ready to do more work
        value = Config::Defaults.syscall_backend.schedule_block(block: block)

        # when transferred back to this fiber, +value+ should be nil
        raise "transferred back to #connect fiber, but came with non-nil info [#{value.inspect}]" if value
      else
        [rc, errno]
      end
    end

    def listen(backlog:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.listen(backlog: backlog, timeout: timeout)
        [rc, errno]
      end
    end

    def accept(timeout: nil)
      rc, errno, address, socket = safe_delegation do |context|
        rc, errno, address, socket = context.accept(timeout: timeout)
        [rc, errno, address, socket]
      end

      [address, socket, rc, errno]
    end

    def each_accept(timeout: nil, &blk)
      return nil unless block_given?
      # when #accept gets a block, loop forever accepting connections
      # As of now, there is no way to exit that loop.
      loop do
        rc, errno, address, socket = safe_delegation do |context|
          context.accept(timeout: timeout)
        end

        block = make_accept_block(rc, errno, address, socket, &blk)

        # Schedule block above to be run
        Config::Defaults.syscall_backend.schedule_block(block: block)
      end
    end

    def accept_break
    end

    def send(buffer:, nbytes:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.send(buffer: buffer, nbytes: nbytes, flags: flags, timeout: timeout)
        [rc, errno]
      end
    end

    def sendto(addr:, buffer:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.sendto(addr: addr, buffer: buffer, flags: flags, timeout: timeout)
        [rc, errno]
      end
    end

    def sendmsg(msghdr:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.sendmsg(msghdr: msghdr, flags: flags, timeout: timeout)
        [rc, errno]
      end
    end

    def recv(buffer:, nbytes:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno, string = context.recv(buffer: buffer, nbytes: nbytes, flags: flags, timeout: timeout)
        [rc, errno, string]
      end
    end

    def recvfrom(addr:, buffer:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.recvfrom(addr: addr, buffer: buffer, flags: flags, timeout: timeout)
        [rc, errno]
      end
    end

    def recvmsg(msghdr:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.recvmsg(msghdr: msghdr, flags: flags, timeout: timeout)
        [rc, errno]
      end
    end


    private

    def safe_delegation
      Config::Defaults.syscall_backend.setup
      yield(@context) if Config::Defaults.multithread_policy.check(io: self, creator: @creator)
    end

    def update_context(behavior)
      @context = behavior
    end

    # Wraps the block given to the accept loop into its own
    # Proc so it can be independently scheduled to run.
    def make_accept_block(rc, errno, address, socket)
      lambda do
        begin
          yield(address, socket, rc, errno)

          # TODO: Need to rescue exceptions and somehow propogate them
          # to surrounding thread. Extra work necessary since Fiber#transfer
          # appears to short circuit the existing mechanisms to do this.
          # Needs more research.
          # Could maybe grab the exception here, wrap it up, and yield
          # it to the block via rc & errno
        rescue => e
          STDERR.puts "ACCEPT_LOOP EXCEPTION! #{e.inspect}, #{e.backtrace.inspect}"
          #raise
        ensure
          # socket may have failed to allocate so it could be nil
          socket.close if socket
        end
      end
    end

    def make_connect_block(socket, rc, errno)
      lambda do
        begin
          val = yield(socket, rc, errno)
          val
        rescue => e
          STDERR.puts "CONNECT_BLOCK EXCEPTION! #{e.inspect}, #{e.backtrace.inspect}"
          # TODO fix... does not propogate up... the ensure block is likely also raising
          # the same exception, so the fiber does not exit and the program hangs.
          #raise
        ensure
          socket.close
        end
      end
    end
  end

  class TCP4 < TCP
    def protocol_version
      '4'
    end
  end

  class TCP6 < TCP
    def protocol_version
      '6'
    end
  end
end
