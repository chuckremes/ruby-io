class IO
  module Internal
    module Backend
      class Sync
        class << self
          def fcntl(fd:, cmd:, args:, timeout:)
            POSIX.fcntl(fd, cmd, args)
          end

          def open(path:, flags:, mode:, timeout:)
            POSIX.open(path, flags.to_i, mode.to_i)
          end

          def close(fd:, timeout:)
            POSIX.close(fd)
          end

          def read(fd:, buffer:, nbytes:, timeout:)
            POSIX.read(fd, buffer, nbytes)
          end

          def write(fd:, buffer:, nbytes:, timeout:)
            POSIX.write(fd, buffer, nbytes)
          end

          def pread(fd:, buffer:, nbytes:, offset:, timeout:)
            POSIX.pread(fd, buffer, nbytes, offset)
          end

          def pwrite(fd:, buffer:, nbytes:, offset:, timeout:)
            POSIX.pwrite(fd, buffer, nbytes, offset)
          end

          def getaddrinfo(hostname:, service:, hints:, results:, timeout:)
            POSIX.getaddrinfo(hostname, service, hints, results)
          end

          def socket(domain:, type:, protocol:, timeout:)
            POSIX.socket(domain, type, protocol)
          end

          def bind(fd:, addr:, addrlen:, timeout:)
            POSIX.bind(fd, addr, addrlen)
          end

          def connect(fd:, addr:, addrlen:, timeout:)
            POSIX.connect(fd, addr, addrlen)
          end

          def listen(fd:, backlog:, timeout:)
            POSIX.listen(fd, backlog)
          end

          def accept(fd:, addr:, addrlen:, timeout:)
            POSIX.accept(fd, addr, addrlen)
          end

          def send(fd:, buffer:, nbytes:, flags:, timeout:)
            POSIX.send(fd, buffer, nbytes, flags)
          end

          def recv(fd:, buffer:, nbytes:, flags:, timeout:)
            POSIX.recv(fd, buffer, nbytes, flags)
          end

          def setup
            # no op
          end

          def schedule_block(block:)
            f = Fiber.new do
              block.call
            end
            f.resume
          end
        end
      end
    end
  end
end
