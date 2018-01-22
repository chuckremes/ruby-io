class IO
  module Internal
    module States
      class Socket
        class Open
          def initialize(fd:, backend:, parent: nil)
            @fd = fd
            @backend = backend
            @parent = parent
          end

          def close(timeout: nil)
            results = @backend.close(fd: @fd, timeout: timeout)
            rc = results[:rc]
            errno = results[:errno]
            if rc.zero? || Errno::EBADF::Errno == errno
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
            results = @backend.bind(fd: @fd, addr: addr, addrlen: addr.size, timeout: timeout)
            if results[:rc] < 0
              [
                results[:rc],
                results[:errno],
                self
              ]
            else
              [
                results[:rc],
                results[:errno],
                Bound.new(fd: @fd, backend: @backend, parent: @parent)
              ]
            end
          end

          def connect(addr:, timeout: nil)
            results = @backend.connect(fd: @fd, addr: addr, addrlen: addr.size, timeout: timeout)
            if results[:rc] < 0
              [results[:rc], results[:errno], self]
            else
              [results[:rc], results[:errno], Connected.new(fd: @fd, backend: @backend)]
            end
          end

          def listen(backlog:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def accept(timeout: nil)
            [-1, Errno::EBADF, nil]
          end

          def send(buffer:, nbytes:, flags:, timeout: nil)
            sendto(addr: nil, buffer: buffer, flags: flags, timeout: timeout)
          end

          def sendto(addr:, buffer:, flags:, timeout: nil)
            sendmsg(msghdr: nil, flags: flags, timeout: timeout)
          end

          def sendmsg(msghdr:, flags:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def recv(buffer:, nbytes:, flags:, timeout: nil)
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
