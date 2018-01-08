class IO
  module Internal
    module Backend
      class Sync
        class << self
          def fcntl(fd:, cmd:, args:, timeout:)
            reply = Platforms::Functions.fcntl(fd, cmd, args)

            #Policy.check(reply)
            reply
          end

          def open(path:, flags:, mode:, timeout:)
            reply = Platforms::Functions.open(path, flags.to_i, mode.to_i)

            #Policy.check(reply)
            reply
          end

          def close(fd:, timeout:)
            reply = Platforms::Functions.close(fd)

            #Policy.check(reply)
            reply
          end

          def read(fd:, buffer:, nbytes:, timeout:)
            reply = Platforms::Functions.read(fd, buffer, nbytes)

            #Policy.check(reply)
            reply
          end

          def write(fd:, buffer:, nbytes:, timeout:)
            reply = Platforms::Functions.write(fd, buffer, nbytes)

            #Policy.check(reply)
            reply
          end

          def pread(fd:, buffer:, nbytes:, offset:, timeout:)
            reply = Platforms::Functions.pread(fd, buffer, nbytes, offset)

            #Policy.check(reply)
            reply
          end

          def wwrite(fd:, buffer:, nbytes:, offset:, timeout:)
            reply = Platforms::Functions.pwrite(fd, buffer, nbytes, offset)

            #Policy.check(reply)
            reply
          end

          def getaddrinfo(hostname:, service:, hints:, results:, timeout:)
            reply = Platforms::Functions.getaddrinfo(hostname, service, hints, results)

            #Policy.check(reply)
            reply
          end

          def socket(domain:, type:, protocol:, timeout:)
            reply = Platforms::Functions.socket(domain, type, protocol)

            #Policy.check(reply)
            reply
          end

          def bind(fd:, addr:, addrlen:, timeout:)
            reply = Platforms::Functions.bind(fd, addr, addrlen)

            #Policy.check(reply)
            reply
          end

          def connect(fd:, addr:, addrlen:, timeout:)
            reply = Platforms::Functions.connect(fd, addr, addrlen)

            #Policy.check(reply)
            reply
          end

          def listen(fd:, backlog:, timeout:)
            reply = Platforms::Functions.listen(fd, backlog)

            #Policy.check(reply)
            reply
          end

          def accept(fd:, addr:, addrlen:, timeout:)
            reply = Platforms::Functions.accept(fd, addr, addrlen)

            #Policy.check(reply)
            reply
          end

          def ssend(fd:, buffer:, flags:, timeout:)
            reply = Platforms::Functions.ssend(fd, buffer, buffer.size, flags)

            #Policy.check(reply)
            reply
          end

          def recv(fd:, buffer:, flags:, timeout:)
            reply = Platforms::Functions.recv(fd, buffer, buffer.size, flags)

            #Policy.check(reply)
            reply
          end
        end
      end
    end
  end
end
