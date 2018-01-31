require 'io/internal/states/socket/closed'
require 'io/internal/states/socket/bound'
require 'io/internal/states/socket/connected'
require 'io/internal/states/socket/unconnected'
require 'io/internal/states/socket/open'

class IO
  class UDP
    class << self
      def open(domain:, type:, protocol:, timeout: nil)
        Config::Defaults.syscall_backend.setup
        result = Config::Defaults.syscall_backend.socket(domain: domain, type: type, protocol: protocol, timeout: timeout)

        if result[:rc] > 0
          if Platforms::PF_INET == domain
            UDP4.new(fd: result[:rc])
          elsif Platforms::PF_INET6 == domain
            UDP6.new(fd: result[:rc])
          else
            # Temporary raise... should respect the set Policy. If socket
            # failed to open, return a TCP socket in the Closed state.
            # UDP.new(fd: nil, state: :closed)
            raise "Unknown Protocol Family [#{domain}] for UDP socket!"
          end
        else
          raise "failed to allocate socket"
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
        hints = Platforms::AddrInfoStruct.new
        hints[:ai_flags] = Platforms::AI_PASSIVE
        hints[:ai_family] = Platforms::AF_UNSPEC
        hints[:ai_socktype] = Platforms::SOCK_DGRAM

        getaddrinfo(hostname: hostname, service: service, hints: hints, timeout: timeout)
      end

      def getv4(hostname:, service:, flags: nil, timeout: nil)
        # FIXME: add a Config::Socket::AddressInfoFlag class to handle ai_flags
        hints = Platforms::AddrInfoStruct.new
        hints[:ai_flags] = Platforms::AI_PASSIVE
        hints[:ai_family] = Platforms::PF_INET
        hints[:ai_socktype] = Platforms::SOCK_DGRAM

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

        begin
          # We don't own the memory containing the addrinfo structs, so we need to copy
          # these to our own memory
          addrinfo = Platforms::AddrInfoStruct.new(ptr)

          if addrinfo[:ai_family] == Platforms::AF_INET
            Platforms::SockAddrInStruct.new(addrinfo[:ai_addr])
          else
            Platforms::SockAddrIn6Struct.new(addrinfo[:ai_addr])
          end

          structs << Platforms::AddrInfoStruct.copy_to_new(addrinfo)

          ptr = addrinfo[:ai_next]
        end while(ptr && !ptr.null?)
        structs
      end
    end

    def initialize(fd:, state: :open, error_policy: nil)
      @creator = Thread.current
      reply = FCNTL.set_nonblocking(fd: fd) # ignore return code?
      @accept_loop = nil

      @context = if :open == state
        Internal::States::Socket::Open.new(
          fd: fd,
          backend: Config::Defaults.syscall_backend,
          parent: self
        )
      elsif :connected == state
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

    def connect(addr:, timeout: nil)
      rc, errno = safe_delegation do |context|
        rc, errno, behavior = context.connect(addr: addr, timeout: timeout)
        update_context(behavior)
        [rc, errno]
      end
      if block_given?
        io = self
        block = Proc.new do
          begin
            yield(io, rc, errno)
          ensure
            close
          end
        end

        # mark current fiber as ready to do more work
        value = Config::Defaults.syscall_backend.schedule_block(originator: Fiber.current, block: block)

        # when transferred back to this fiber, +value+ should be nil
        raise "transferred back to #connect fiber, but came with non-nil info [#{value.inspect}]" if value
      else
        [rc, errno]
      end
    end

    def listen(backlog:, timeout: nil)
      [-1, Errno::EOPNOTSUPP]
    end

    def accept(timeout: nil)
      [-1, Errno::EOPNOTSUPP]
    end

    def send(buffer:, nbytes:, flags:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.send(buffer: buffer, nbytes: nbytes, flags: flags, timeout: timeout)
        [rc, errno]
      end
    end

    def sendto(buffer:, nbytes:, flags:, addr:, addr_len:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.sendto(
          buffer: buffer,
          nbytes: nbytes,
          flags: flags,
          addr: addr,
          addr_len: addr_len,
          timeout: timeout
        )
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

    def recvfrom(buffer:, nbytes:, flags:, addr:, addr_len:, timeout: nil)
      safe_delegation do |context|
        rc, errno, string, addr, addr_len = context.recvfrom(
          buffer: buffer,
          nbytes: nbytes,
          flags: flags,
          addr: addr,
          addr_len: addr_len,
          timeout: timeout
        )
        [rc, errno, string, addr, addr_len]
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
      if Config::Defaults.multithread_policy.check(io: self, creator: @creator)
        yield @context
      end
    end

    def update_context(behavior)
      @context = behavior
    end
  end

  class UDP4 < UDP
    class << self
      def allocate_addr_buffer
        addr_buffer = Platforms::SockAddrInStruct.new
        addr_len = ::FFI::MemoryPointer.new(:socklen_t)
        addr_len.write_uint32(addr_buffer.size)
        [addr_buffer, addr_len]
      end
    end

    def protocol_version() '4'; end
  end

  class UDP6 < UDP
    class << self
      def allocate_addr_buffer
        addr_buffer = Platforms::SockAddrIn6Struct.new
        addr_len = ::FFI::MemoryPointer.new(:socklen_t)
        addr_len.write_uint32(addr_buffer.size)
        [addr_buffer, addr_len]
      end
    end

    def protocol_version() '6'; end
  end
end
