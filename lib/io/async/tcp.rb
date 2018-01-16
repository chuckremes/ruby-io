require 'io/internal/states/socket/closed'
require 'io/internal/states/socket/bound'
require 'io/internal/states/socket/connected'
require 'io/internal/states/socket/open'

class IO
  module Async

    class TCP
      class << self
        def open(domain:, type:, protocol:, timeout: nil)
          Private.setup
          result = Internal::Backend::Async.socket(domain: domain, type: type, protocol: protocol, timeout: timeout)

          if result[:rc] > 0
            if Platforms::PF_INET == domain
              TCP4.new(fd: result[:rc])
            elsif Platforms::PF_INET6 == domain
              TCP6.new(fd: result[:rc])
            else
              # Temporary raise... should respect the set Policy. If socket
              # failed to open, return a TCP socket in the Closed state.
              # TCP.new(fd: nil, state: :closed)
              raise "Unknown Protocol Family [#{domain}] for TCP socket!"
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
          hints[:ai_socktype] = Platforms::SOCK_STREAM

          getaddrinfo(hostname: hostname, service: service, hints: hints, timeout: timeout)
        end

        def getv4(hostname:, service:, flags: nil, timeout: nil)
          # FIXME: add a Config::Socket::AddressInfoFlag class to handle ai_flags
          hints = Platforms::AddrInfoStruct.new
          hints[:ai_flags] = Platforms::AI_PASSIVE
          hints[:ai_family] = Platforms::PF_INET
          hints[:ai_socktype] = Platforms::SOCK_STREAM

          getaddrinfo(hostname: hostname, service: service, hints: hints, timeout: timeout)
        end

        def getaddrinfo(hostname:, service:, hints:, timeout: nil)
          Private.setup
          results = ::FFI::MemoryPointer.new(:pointer)
          result = Internal::Backend::Async.getaddrinfo(hostname: hostname, service: service, hints: hints, results: results, timeout: timeout)
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
          Internal::States::TCP::Open.new(fd: fd, backend: Internal::Backend::Async, parent: self)
        elsif :connected == state
          Internal::States::TCP::Connected.new(fd: fd, backend: Internal::Backend::Async)
        else
          Internal::States::TCP::Closed.new(fd: -1, backend: Internal::Backend::Async)
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
          value = Thread.current.local[:_scheduler_].schedule_fibers(originator: Fiber.current, spawned: block)

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
        if block_given? && @accept_loop.nil?
          @accept_loop = true
          # when #accept gets a block, loop forever accepting connections
          # this won't work until I get +timeout+ hooked up and functional.
          while @accept_loop
            begin
              rc, errno, address, socket = safe_delegation do |context|
                rc, errno, address, socket = context.accept(timeout: timeout)
                [rc, errno, address, socket]
              end

              block = Proc.new do
                begin
                  yield(address, socket, rc, errno)
                ensure
                  socket.close if socket.respond_to?(:close)
                end
              end

              # Schedule block above to be run
              value = Thread.current.local[:_scheduler_].schedule_fibers(originator: Fiber.current, spawned: block)

              # when transferred back to this fiber, +value+ should be nil
              raise "transferred back to #connect fiber, but came with non-nil info [#{value.inspect}]" if value
            end
          end
          @accept_loop = nil
        else
          rc, errno, address, socket = safe_delegation do |context|
            rc, errno, address, socket = context.accept(timeout: timeout)
            [rc, errno, address, socket]
          end

          [address, socket, rc, errno]
        end
      end

      def accept_break
        @accept_loop = false
      end

      def ssend(buffer:, nbytes:, flags:, timeout: nil)
        safe_delegation do |context|
          rc, errno = context.ssend(buffer: buffer, nbytes: nbytes, flags: flags, timeout: timeout)
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
        Private.setup
        if Config::Defaults.multithread_policy.check(io: self, creator: @creator)
          yield @context
        end
      end

      def update_context(behavior)
        @context = behavior
      end
    end

    class TCP4 < TCP
      def protocol_version() '4'; end
    end

    class TCP6 < TCP
      def protocol_version() '6'; end
    end
  end
end
