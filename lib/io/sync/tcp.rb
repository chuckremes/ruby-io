require 'io/internal/states/socket/closed'
require 'io/internal/states/socket/bound'
require 'io/internal/states/socket/connected'
require 'io/internal/states/socket/open'

class IO
  module Sync

    class TCP
      class << self
        def open(domain:, type:, protocol:)
          result = Internal::Backend::Sync.socket(domain: domain, type: type, protocol: protocol, timeout: nil)

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

        def ip4(addrinfo:)
          open(
          domain: addrinfo[:ai_family],
          type: addrinfo[:ai_socktype], 
          protocol: addrinfo[:ai_protocol])
        end

        def getallstreams(hostname:, service:)
          hints = Platforms::AddrInfoStruct.new
          hints[:ai_flags] = Platforms::AI_PASSIVE
          hints[:ai_family] = Platforms::AF_UNSPEC
          hints[:ai_socktype] = Platforms::SOCK_STREAM

          getaddrinfo(hostname: hostname, service: service, hints: hints)
        end

        def getv4(hostname:, service:, flags: nil)
          # FIXME: add a Config::Socket::AddressInfoFlag class to handle ai_flags
          hints = Platforms::AddrInfoStruct.new
          hints[:ai_flags] = Platforms::AI_PASSIVE
          hints[:ai_family] = Platforms::PF_INET
          hints[:ai_socktype] = Platforms::SOCK_STREAM

          getaddrinfo(hostname: hostname, service: service, hints: hints)
        end
        
        def getaddrinfo(hostname:, service:, hints:)
          results = ::FFI::MemoryPointer.new(:pointer)
          result = Internal::Backend::Sync.getaddrinfo(hostname: hostname, service: service, hints: hints, results: results, timeout: nil)
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
        @policy = error_policy || Config::Defaults.error_policy

        @context = if :open == state
          Internal::States::Socket::Open.new(fd: fd, backend: Internal::Backend::Sync, parent: self)
        elsif :connected == state
          Internal::States::Socket::Connected.new(fd: fd, backend: Internal::Backend::Sync)
        else
          Internal::States::Socket::Closed.new(fd: -1, backend: Internal::Backend::Sync)
        end
      end

      def close
        safe_delegation do |context|
          rc, errno, behavior = context.close
          [rc, errno]
        end
      end
      
      def bind(addr:)
        safe_delegation do |context|
          rc, errno, behavior = context.bind(addr: addr)
          update_context(behavior)
          [rc, errno]
        end
      end

      def connect(addr:)
        safe_delegation do |context|
          rc, errno, behavior = context.connect(addr: addr)
          update_context(behavior)
          [rc, errno]
        end
      end
      
      def listen(backlog:)
        safe_delegation do |context|
          rc, errno = context.listen(backlog: backlog)
          [rc, errno]
        end
      end
      
      def accept
        rc, errno, address, socket = safe_delegation do |context|
          rc, errno, address, socket = context.accept
          [rc, errno, address, socket]
        end
        block_given? ? yield(address, socket, rc, errno) : [address, socket, rc, errno]
      end

      def send(buffer:, nbytes:, flags:)
        safe_delegation do |context|
          rc, errno = context.send(buffer: buffer, nbytes: nbytes, flags: flags)
          [rc, errno]
        end
      end
      
      def sendto(addr:, buffer:, flags:)
        safe_delegation do |context|
          rc, errno = context.sendto(addr: addr, buffer: buffer, flags: flags)
          [rc, errno]
        end
      end
      
      def sendmsg(msghdr:, flags:)
        safe_delegation do |context|
          rc, errno = context.sendmsg(msghdr: msghdr, flags: flags)
          [rc, errno]
        end
      end

      def recv(buffer:, nbytes:, flags:, timeout: nil)
        safe_delegation do |context|
          rc, errno, string = context.recv(buffer: buffer, nbytes: nbytes, flags: flags, timeout: timeout)
          [rc, errno, string]
        end
      end
      
      def recvfrom(addr:, buffer:, flags:)
        safe_delegation do |context|
          rc, errno = context.recvfrom(addr: addr, buffer: buffer, flags: flags)
          [rc, errno]
        end
      end
      
      def recvmsg(msghdr:, flags:)
        safe_delegation do |context|
          rc, errno = context.recvmsg(msghdr: msghdr, flags: flags)
          [rc, errno]
        end
      end


      private
      
      def safe_delegation
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
