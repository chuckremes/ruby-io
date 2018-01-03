class IO
  module Internal
    module States
      class TCP
        class Closed
          def initialize(fd:, backend:, parent: nil)
            @fd = fd
            @backend = backend
          end

          def close(timeout: nil)
            [-1, Errno::EBADF]
          end

          def bind(addr:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def connect(addr:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def listen(backlog:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def accept(addr:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def ssend(buffer:, flags:, timeout: nil)
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
