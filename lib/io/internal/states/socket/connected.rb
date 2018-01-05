class IO
  module Internal
    module States
      class TCP
        class Connected
          def initialize(fd:, backend:, parent: nil)
            @fd = fd
            @backend = backend
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
            [-1, Errno::EINVAL]
          end

          def accept(timeout: nil)
            [-1, Errno::EINVAL]
          end

          def ssend(buffer:, flags:, timeout: nil)
            results = @backend.ssend(fd: @fd, buffer: buffer, flags: flags, timeout: timeout)
            [result[:rc], results[:errno]]
          end

          def sendto(addr:, buffer:, flags:, timeout: nil)
            sendmsg(msghdr: nil, flags: flags, timeout: timeout)
          end

          def sendmsg(msghdr:, flags:, timeout: nil)
            [-1, Errno::EBADF]
          end

          def recv(buffer:, flags:, timeout: nil)
            results = @backend.recv(fd: @fd, buffer: buffer, flags: flags, timeout: timeout)
            [result[:rc], results[:errno], buffer.read_string]
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
