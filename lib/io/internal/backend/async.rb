require_relative 'async/poller'

class IO
  module Internal
    module Backend
      class Async
        class << self
          def fcntl(fd:, cmd:, args:, timeout:)
            request = IO::Async::Private::Request::Fcntl.new(
              Fiber.current,
              fd: fd,
              cmd: cmd,
              args: args,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def open(path:, flags:, mode:, timeout:)
            request = IO::Async::Private::Request::Open.new(
              Fiber.current,
              path: path,
              flags: flags,
              mode: mode,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def close(fd:, timeout:)
            request = IO::Async::Private::Request::Close.new(
              Fiber.current,
              fd: fd,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def read(fd:, buffer:, nbytes:, timeout:)
            request = IO::Async::Private::Request::Read.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def write(fd:, buffer:, nbytes:, timeout:)
            request = IO::Async::Private::Request::Write.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              timeout: timeout
            )
            reply = enqueue(request)
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
          end

          def pwrite(fd:, buffer:, nbytes:, offset:, timeout:)
            request = IO::Async::Private::Request::PWrite.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              offset: offset,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def getaddrinfo(hostname:, service:, hints:, results:, timeout:)
            build_blocking_request do |fiber|
              build_command(fiber) do
                Platforms::Functions.getaddrinfo(hostname, service, hints, results)
              end
            end
#            request = IO::Async::Private::Request::Getaddrinfo.new(
#              Fiber.current,
#              hostname: hostname,
#              service: service,
#              hints: hints,
#              results: results,
#              timeout: timeout
#            )
#            reply = enqueue(request)
          end

          def socket(domain:, type:, protocol:, timeout:)
            request = IO::Async::Private::Request::Socket.new(
              Fiber.current,
              domain: domain,
              type: type,
              protocol: protocol,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def getsockopt(fd:, level:, option_name:, value:, length:, timeout:)
            request = IO::Async::Private::Request::Getsockopt.new(
              Fiber.current,
              fd: fd,
              level: level,
              option_name: option_name,
              value: value,
              length: length,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def bind(fd:, addr:, addrlen:, timeout:)
            request = IO::Async::Private::Request::Bind.new(
              Fiber.current,
              fd: fd,
              addr: addr,
              addrlen: addrlen,
              timeout: timeout
            )
            reply = enqueue(request)
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
            Logger.debug(klass: self.class, name: :connect, message: "[#{tid}], starting nonblocking connect")
            reply = Platforms::Functions.connect(fd, addr, addrlen)
            Logger.debug(klass: self.class, name: :connect, message: "[#{tid}], #{reply.inspect}")
            return reply if reply[:rc].zero? || connect_failed?(reply)

            # step 3
            Logger.debug(klass: self.class, name: :connect, message: "[#{tid}], nonblocking connect step 3")
            request = IO::Async::Private::Request::Connect.new(
              Fiber.current,
              fd: fd,
              timeout: timeout
            )
            reply = enqueue(request)
            Logger.debug(klass: self.class, name: :connect, message: "[#{tid}], nonblocking connect fd is writeable")

            # step 5
            Logger.debug(klass: self.class, name: :connect, message: "[#{tid}], nonblocking connect check SO_ERROR")
            error = ::FFI::MemoryPointer.new(:int)
            reply = getsockopt(
              fd: fd,
              level: Constants::SockOpt::SOL_SOCKET,
              option_name: Constants::SockOpt::SO_ERROR,
              value: error,
              length: error.size
            )

            # step 6
            Logger.debug(klass: self.class, name: :connect, message: "[#{tid}], nonblocking connect step 6")
            reply[:errno] = error.read_int if reply[:rc] < 0
            reply
          end

          def connect_failed?(reply)
            return false if reply[:rc].zero?
            errno = reply[:errno]

            errno != Errno::EINPROGRESS::Errno
          end

          def listen(fd:, backlog:, timeout:)
            request = IO::Async::Private::Request::Listen.new(
              Fiber.current,
              fd: fd,
              backlog: backlog,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def accept(fd:, addr:, addrlen:, timeout:)
            request = IO::Async::Private::Request::Accept.new(
              Fiber.current,
              fd: fd,
              addr: addr,
              addrlen: addrlen,
              timeout: timeout
            )
            reply = enqueue(request)
          end

          def send(fd:, buffer:, nbytes:, flags:, timeout:)
            request = IO::Async::Private::Request::Send.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              flags: flags,
              timeout: timeout
            )
            reply = enqueue(request)
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
            request = IO::Async::Private::Request::Recv.new(
              Fiber.current,
              fd: fd,
              buffer: buffer,
              nbytes: nbytes,
              flags: flags,
              timeout: timeout
            )
            reply = enqueue(request)
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
            request = IO::Async::Private::Request::Timer.new(
              Fiber.current,
              duration: duration
            )
            reply = enqueue(request)
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
            Fiber.current.local[:_now_] ||= Time.now
            secs = Time.now - Fiber.current.local[:_now_]
            c = caller.join(', ')
            Logger.debug(klass: self.class, name: :enqueue, message: "[#{tid}], [#{secs}] spent in this fiber, #{c.inspect}")
            reply = Thread.current.local[:_scheduler_].schedule_request(request)
            Fiber.current.local[:_now_] = Time.now

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

          def schedule_block(originator:, block:)
            value = Thread.current.local[:_scheduler_].schedule_block(originator: originator, block: block)
            # when transferred back to this fiber, +value+ should be nil
            raise "transferred back to #connect fiber, but came with non-nil info [#{value.inspect}]" if value
          end
        end
      end
    end
  end
end
