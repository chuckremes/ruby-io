class IO
  module Internal
    module Backend
      class Sync
        class << self
          def fcntl(fd:, cmd:, args:, timeout:)
            Platforms::Functions.fcntl(fd, cmd, args)
          end

          def open(path:, flags:, mode:, timeout:)
            Platforms::Functions.open(path, flags.to_i, mode.to_i)
          end

          def close(fd:, timeout:)
            Platforms::Functions.close(fd)
          end

          def read(fd:, buffer:, nbytes:, timeout:)
            Platforms::Functions.read(fd, buffer, nbytes)
          end

          def write(fd:, buffer:, nbytes:, timeout:)
            Platforms::Functions.write(fd, buffer, nbytes)
          end

          def pread(fd:, buffer:, nbytes:, offset:, timeout:)
            Platforms::Functions.pread(fd, buffer, nbytes, offset)
          end

          def pwrite(fd:, buffer:, nbytes:, offset:, timeout:)
            Platforms::Functions.pwrite(fd, buffer, nbytes, offset)
          end

          def getaddrinfo(hostname:, service:, hints:, results:, timeout:)
            Platforms::Functions.getaddrinfo(hostname, service, hints, results)
          end

          def socket(domain:, type:, protocol:, timeout:)
            Platforms::Functions.socket(domain, type, protocol)
          end

          def bind(fd:, addr:, addrlen:, timeout:)
            Platforms::Functions.bind(fd, addr, addrlen)
          end

          def connect(fd:, addr:, addrlen:, timeout:)
            Platforms::Functions.connect(fd, addr, addrlen)
          end

          def listen(fd:, backlog:, timeout:)
            Platforms::Functions.listen(fd, backlog)
          end

          def accept(fd:, addr:, addrlen:, timeout:)
            Platforms::Functions.accept(fd, addr, addrlen)
          end

          def ssend(fd:, buffer:, nbytes:, flags:, timeout:)
            Platforms::Functions.ssend(fd, buffer, nbytes, flags)
          end

          def recv(fd:, buffer:, nbytes:, flags:, timeout:)
            Platforms::Functions.recv(fd, buffer, nbytes, flags)
          end
        end
      end
    end
  end
end
