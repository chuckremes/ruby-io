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
            request = IO::Async::Private::Request::Close.new(
              Fiber.current,
              fd: fd,
              timeout: timeout
            )
            reply = enqueue(request)

            #            build_blocking_request do |fiber|
            #              build_command(fiber) do
            #                Platforms::Functions.close(fd)
            #              end
            #            end
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

          def getsockopt(fd:, level:, option_name:, value:, length:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.getsockopt(fd, level, option_name, value, length)
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

          # Non-blocking connect is somewhat complicated. The steps are:
          # 1. Issue a non-blocking connect request
          # 2. If returns 0, succeeded immediately and can continue
          # 3. If returns -1 and EAGAIN/EWOULDBLOCK, then issue an async
          #    request on this FD to see when it becomes writable. This
          #    indicates the #connect has completed.
          # 4. Writable callback should do nothing more than return. Next
          #    step is important.
          # 5. Issue #getsockopt call to retrieve SO_ERROR.
          # 6. If error is 0, connect completed successfully. If
          #    non-zero, this is errno and should be reported back to
          #    caller.
          #
          # Fitting all of these steps in here is crucial.
          def connect(fd:, addr:, addrlen:, timeout:)
            reply = Platforms::Functions.connect(fd, addr, addrlen)
            return reply if reply[:rc].zero? || connect_failed?(reply)

            # step 3
            reply = build_poll_write_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                # step 4
                { writeable: true }
              end
            end

            # step 5
            error = ::FFI::MemoryPointer.new(:int)
            reply = getsockopt(
              fd: fd,
              level: Constants::SockOpt::SOL_SOCKET,
              option_name: Constants::SockOpt::SO_ERROR,
              value: error,
              length: error.size
            )

            # step 6
            reply[:errno] = error.read_int if reply[:rc] < 0
            reply
          end

          def connect_failed?(reply)
            return false if reply[:rc].zero?
            errno = reply[:errno]

            errno != Errno::EINPROGRESS::Errno
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

          def send(fd:, buffer:, nbytes:, flags:, timeout:)
            build_poll_write_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.send(fd, buffer, nbytes, flags.to_i)
              end
            end
          end

          def sendto(fd:, buffer:, nbytes:, flags:, addr:, addr_len:, timeout:)
            request = IO::Async::Private::Request::Sendto.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              flags: flags,
              addr: addr,
              addr_len: addr_len,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def recv(fd:, buffer:, nbytes:, flags:, timeout:)
            build_poll_read_request(fd: fd, repeat: false) do |fiber|
              build_command(fiber) do
                Platforms::Functions.recv(fd, buffer, nbytes, flags.to_i)
              end
            end
          end

          def recvfrom(fd:, buffer:, nbytes:, flags:, addr:, addr_len:, timeout:)
            request = IO::Async::Private::Request::Recvfrom.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              flags: flags,
              addr: addr,
              addr_len: addr_len,
              timeout: timeout
            )
            reply = enqueue(request)
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
            reply = Thread.current.local[:_scheduler_].schedule_request(request)

            while true
              if reply.nil?
                Logger.debug(klass: self.class, name: :enqueue, message: "[#{tid}], reply was nil, reschedule fiber")
                reply = Thread.current.local[:_scheduler_].reschedule_me
              end
              if reply
                Logger.debug(klass: self.class, name: :enqueue, message: "[#{tid}], good reply")
                break
              else
                Logger.debug(klass: self.class, name: :enqueue, message: "[#{tid}], reply was nil AGAIN, reschedule fiber")
              end
            end
            raise "#{tid}, #{self.class}#schedule_request, reply is wrong! [#{fid}], #{reply.inspect}" unless reply
            reply
          end

          def next_sequence_number
            Fiber.current.local[:sequence_no] += 1
          end

          def setup
            IO::Async::Private::Configure.setup
          end

          def schedule_fibers(originator:, spawned:)
            value = Thread.current.local[:_scheduler_].schedule_fibers(originator: originator, spawned: spawned)
            # when transferred back to this fiber, +value+ should be nil
            raise "transferred back to #connect fiber, but came with non-nil info [#{value.inspect}]" if value
          end
        end
      end
    end
  end
end
