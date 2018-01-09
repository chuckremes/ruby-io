require_relative 'async/poller'

class IO
  module Internal
    module Backend
      class Async
        class << self
          def fcntl(fd:, cmd:, args:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.fcntl(fd, cmd, args)
              end
            end
          end

          def open(path:, flags:, mode:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.open(path, flags.to_i, mode.to_i)
              end
            end
          end

          def close(fd:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.close(fd)
              end
            end
          end

          def read(fd:, buffer:, nbytes:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.read(fd, buffer, nbytes)
              end
            end
          end

          def write(fd:, buffer:, nbytes:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.write(fd, buffer, nbytes)
              end
            end
          end

          def pread(fd:, buffer:, nbytes:, offset:, timeout:)
            request = IO::Async::Private::Request::PRead.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              offset: offset,
              timeout: timeout
            )
            reply = enqueue(request)
            #            build_blocking_request do |fiber|
            #              build_command(fiber) do
            #                Platforms::Functions.pread(fd, buffer, nbytes, offset)
            #              end
            #            end
          end

          def pwrite(fd:, buffer:, nbytes:, offset:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.pwrite(fd, buffer, nbytes, offset)
              end
            end
          end

          def getaddrinfo(hostname:, service:, hints:, results:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.getaddrinfo(hostname, service, hints, results)
              end
            end
          end

          def socket(domain:, type:, protocol:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.socket(domain, type, protocol)
              end
            end
          end

          def bind(fd:, addr:, addrlen:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.bind(fd, addr, addrlen)
              end
            end
          end

          def connect(fd:, addr:, addrlen:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.connect(fd, addr, addrlen)
              end
            end
          end

          def listen(fd:, backlog:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.listen(fd, backlog)
              end
            end
          end

          def accept(fd:, addr:, addrlen:, timeout:)
            build_poll_read_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.accept(fd, addr, addrlen)
              end
            end
          end

          def ssend(fd:, buffer:, flags:, timeout:)
            build_poll_write_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.ssend(fd, buffer, buffer.size, flags.to_i)
              end
            end
          end

          def recv(fd:, buffer:, flags:, timeout:)
            build_poll_read_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.recv(fd, buffer, buffer.size, flags.to_i)
              end
            end
          end

          def timer(duration:)
            start = Time.now.to_f
            reply = build_timer_request(duration: duration, repeat: false) do |fiber|
              build_command(fiber) do
                {
                  actual_duration: (Time.now.to_f - start)
                }
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
            # Expects the Platforms::Functions call to return a reply as a hash! See
            # code at Platforms::Functions.reply
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
