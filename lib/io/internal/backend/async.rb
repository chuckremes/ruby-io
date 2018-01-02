require_relative 'async/poller'

class IO
  module Internal
    module Backend
      class Async
        class << self
          def fcntl(fd:, cmd:, args:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.fcntl(fd, cmd, args)
              end
            end

            #Policy.check(reply)
            reply
          end

          def open(path:, flags:, mode:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.open(path, flags.to_i, mode.to_i)
              end
            end

            #Policy.check(reply)
            reply
          end

          def close(fd:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.close(fd)
              end
            end

            #Policy.check(reply)
            reply
          end

          def read(fd:, buffer:, nbytes:, offset:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.read(fd, buffer, nbytes, offset)
              end
            end

            #Policy.check(reply)
            reply
          end

          def write(fd:, buffer:, nbytes:, offset:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.write(fd, buffer, nbytes, offset)
              end
            end

            #Policy.check(reply)
            reply
          end

          def getaddrinfo(hostname:, service:, hints:, results:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.getaddrinfo(hostname, service, hints, results)
              end
            end

            #Policy.check(reply)
            reply
          end

          def socket(domain:, type:, protocol:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.socket(domain, type, protocol)
              end
            end

            #Policy.check(reply)
            reply
          end

          def bind(fd:, addr:, addrlen:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.bind(fd, addr, addrlen)
              end
            end

            #Policy.check(reply)
            reply
          end

          def connect(fd:, addr:, addrlen:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.connect(fd, addr, addrlen)
              end
            end

            #Policy.check(reply)
            reply
          end

          def listen(fd:, backlog:, timeout:)
            reply = build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.listen(fd, backlog)
              end
            end

            #Policy.check(reply)
            reply
          end

          def accept(fd:, addr:, addrlen:, timeout:)
            reply = build_poll_read_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.accept(fd, addr, addrlen)
              end
            end

            #Policy.check(reply)
            reply
          end

          def ssend(fd:, buffer:, flags:, timeout:)
            reply = build_poll_write_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.ssend(fd, buffer, buffer.size, flags.to_i)
              end
            end

            #Policy.check(reply)
            reply
          end

          def recv(fd:, buffer:, flags:, timeout:)
            reply = build_poll_read_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.recv(fd, buffer, buffer.size, flags.to_i)
              end
            end

            #Policy.check(reply)
            reply
          end

          def timer(duration:)
            reply = build_timer_request(duration: duration, repeat: false) do |fiber|
              build_command(fiber) do
                # return empty hash to receive :fiber key;
                # necessary so correct fiber can be resumed/transferred from caller
                {}
              end
            end

            reply
          end

          #
          # Helpers for building the asynchronous requests
          #

          def build_blocking_request
            request = IO::Async::Private::Request::BlockingCommand.new(fiber: Fiber.current) do |fiber|
              yield(fiber)
            end
          
            reply = enqueue(request)
          end
          
          def build_poll_read_request(repeat:, fd:)
            request = IO::Async::Private::Request::NonblockingReadCommand.new(fiber: Fiber.current, fd: fd) do |fiber|
              yield(fiber)
            end
          
            reply = enqueue(request)
          end
          
          def build_poll_write_request(repeat:, fd:)
            request = IO::Async::Private::Request::NonblockingWriteCommand.new(fiber: Fiber.current, fd: fd) do |fiber|
              yield(fiber)
            end
          
            reply = enqueue(request)
          end

          def build_timer_request(repeat:, duration:)
            request = IO::Async::Private::Request::NonblockingTimerCommand.new(fiber: Fiber.current, duration: duration) do |fiber|
              yield(fiber)
            end

            reply = enqueue(request)
          end

          def build_command(fiber)
            results = yield
            results[:fiber] = fiber
            results
          end

          def enqueue(request)
            request.sequence_no = next_sequence_number
            Thread.current.local[:_scheduler_].enqueue(request)
          end

          def next_sequence_number
            Fiber.current.local[:sequence_no] += 1
          end
        
          def setup
            Configure.setup
          end
        end
      end
    end
  end
end
