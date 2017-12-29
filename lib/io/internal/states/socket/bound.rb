class IO
  module Internal
    module States
      class TCP
        class Bound
          def initialize(fd:, backend:, parent: nil)
            @fd = fd
            @backend = backend
            @parent = parent
          end

          def close(timeout: nil)
            results = @backend.close(fd: @fd, timeout: timeout)
            rc = results[:rc]
            if rc.zero? || Errno::EBADF == rc
              [0, nil, Closed.new(fd: -1, backend: @backend)]
            else
              if Errno::EINTR == rc
                [-1, nil, self]
              elsif Errno::EIO == rc
                [-1, nil, self]
              else
                # We have encountered a bug; fail hard regardless of Policy
                STDERR.puts "Fatal error: close(2) returned code [#{rc}] and errno [#{errno}] which is an exceptional unhandled case"
                exit!(123)
              end
            end
          end

          def bind(addr:, timeout: nil)
            # Can only bind once!
            [-1, Errno::EINVAL]
          end

          def connect(addr:, timeout: nil)
            # Can only connect once!
            [-1, Errno::EINVAL]
          end

          def listen(backlog:, timeout: nil)
            results = @backend.listen(fd: @fd, backlog: backlog, timeout: timeout)
            if results[:rc] < 0
              [results[:rc], results[:errno], self]
            else
              [results[:rc], nil, self]
            end
          end

          def accept(timeout: nil)
            addr = Platforms::SockAddrStorageStruct.new
            addrlen = Platforms::SockLenStruct.new
            addrlen[:socklen] = addr.size
            results = @backend.accept(fd: @fd, addr: addr, addrlen: addrlen, timeout: timeout)
            p results

            if results[:rc] < 0
              [results[:rc], results[:errno], nil]
            else
              addr = if addr[:ss_family] == Platforms::AF_INET
                Platforms::SockAddrInStruct.copy_to_new(Platforms::SockAddrInStruct.new(addr.pointer))
              else
                Platforms::SockAddrIn6Struct.copy_to_new(Platforms::SockAddrIn6Struct.new(addr.pointer))
              end

              socket = @parent.class.new(fd: results[:rc], state: :connected)

              [results[:rc], nil, addr, socket]
            end
          end

          def send(buffer:, flags:, timeout: nil)
            sendto(addr: nil, buffer: buffer, flags: flags, timeout: timeout)
          end

          def sendto(addr:, buffer:, flags:, timeout: nil)
            sendmsg(msghdr: nil, flags: flags, timeout: timeout)
          end

          def sendmsg(msghdr:, flags:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def recv(buffer:, flags:, timeout: nil)
            recvfrom(addr: nil, buffer: buffer, flags: flags, timeout: timeout)
          end

          def recvfrom(addr:, buffer:, flags:, timeout: nil)
            recvmsg(msghdr: nil, flags: flags, timeout: timeout)
          end

          def recvmsg(msghdr:, flags:, timeout: nil)
            [-1, Errno::EBADF]
          end
        end
      end
    end
  end
end
