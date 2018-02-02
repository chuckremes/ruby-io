class IO
  module Async
    module Private
      module Request

        # An experiment in replacing the Command classes. Major difference
        # is that we avoid capturing a block and calling it like in the
        # Command classes. Calling a block is *far slower* than yielding
        # a block, so there's a possibility that this could be a minor
        # performance enhancement. Preliminary tests show now improvement
        # but we'll keep around this example for a later revisit.
        class BaseCommand
          attr_reader :sequence_no
          attr_reader :fiber
          def initialize(fiber, **kwargs)
            @fiber = fiber
            @kwargs = kwargs
            @creation = Time.now
            @klass_name = self.class.to_s.downcase.split('::').last
          end

          def sequence_no=(val)
            @sequence_no = "#{@klass_name}-#{@fiber.hash}-#{val}"
          end

          def reply_to_mailbox(mailbox)
            @mailbox = mailbox
          end

          def finish_setup
            @promise = Promise.new(mailbox: @mailbox)
          end

          def execute
            executing = Time.now
            secs = executing - @creation
            Logger.debug(klass: self.class, name: 'execute', message: "[#{secs}] phase 1, seq [#{sequence_no}]")
            results = yield(@kwargs.values)

            secs = Time.now - executing
            Logger.debug(klass: self.class, name: 'execute', message: "[#{secs}] phase 2, seq [#{sequence_no}]")
            results[:fiber] = @fiber
            results[:_sequence_no_] = sequence_no
            @promise.fulfill(results)
          end

          def selector_update(poller:)
            # no op by default
          end
        end

        class BaseBlocking < BaseCommand
          def blocking?(); true; end
        end

        class BaseNonblocking < BaseCommand
          def blocking?(); false; end
        end

        class PRead < BaseBlocking
          def call
            execute do |fd, buffer, nbytes, offset, timeout|
              Platforms::Functions.pread(fd, buffer, nbytes, offset)
            end
          end
        end

        class Read < BaseBlocking
          def call
            execute do |fd, buffer, nbytes, timeout|
              Platforms::Functions.read(fd, buffer, nbytes)
            end
          end
        end

        class Close < BaseBlocking
          def call
            execute do |fd, timeout|
              Platforms::Functions.close(fd)
            end
          end

          def selector_update(poller:)
            super

            # tell, don't ask
            poller.deregister(fd: @kwargs[:fd])
          end
        end

        class Open < BaseBlocking
          def call
            execute do |path, flags, mode, timeout|
              Platforms::Functions.open(path, flags.to_i, mode.to_i)
            end
          end
        end

        class Socket < BaseBlocking
          def call
            execute do |domain, type, protocol, timeout|
              Platforms::Functions.socket(domain, type, protocol)
            end
          end
        end

        class Getaddrinfo < BaseBlocking
          def call
            execute do |hostname, service, hints, results, timeout|
              Platforms::Functions.getaddrinfo(hostname, service, hints, results)
            end
          end

          # Need to override for this specific one since attempting to inspect
          # +hints+ or +results+ results in a null pointer exception from FFI.
          def inspect
            "hostname [#{@kwargs[:hostname]}], service [#{@kwargs[:service]}]"
          end
        end

        class Getsockopt < BaseBlocking
          def call
            execute do |fd, level, option_name, value, length, timeout|
              Platforms::Functions.getsockopt(fd, level, option_name, value, length)
            end
          end
        end

        class Fcntl < BaseBlocking
          def call
            execute do |fd, cmd, args, timeout|
              Platforms::Functions.fcntl(fd, cmd, args)
            end
          end
        end

        class Bind < BaseBlocking
          def call
            execute do |fd, addr, addrlen, timeout|
              Platforms::Functions.bind(fd, addr, addrlen)
            end
          end
        end

        class Listen < BaseBlocking
          def call
            execute do |fd, backlog, timeout|
              Platforms::Functions.listen(fd, backlog)
            end
          end
        end

        class Accept < BaseNonblocking
          def call
            execute do |fd, addr, addrlen, timeout|
              Platforms::Functions.accept(fd, addr, addrlen)
            end
          end

          def selector_update(poller:)
            super

            poller.register_read(fd: @kwargs[:fd], request: self)
          end
        end

        class Connect < BaseNonblocking
          def call
            execute do |fd, timeout|
              # When doing a nonblocking connect, we are just waiting for
              # the fd to become writeable. The syscall was already made
              # so another one would just raise an error to no purpose.
              # Could just pass back nil, but I like this so it shows
              # in the log when running in debug mode.
              {
                writeable: true
              }
            end
          end

          def selector_update(poller:)
            super

            poller.register_write(fd: @kwargs[:fd], request: self)
          end
        end

        class Recv < BaseNonblocking
          def call
            execute do |fd, buffer, nbytes, flags, timeout|
              Platforms::Functions.recv(fd, buffer, nbytes, flags)
            end
          end

          def selector_update(poller:)
            super

            poller.register_read(fd: @kwargs[:fd], request: self)
          end
        end

        class Recvfrom < BaseNonblocking
          def call
            execute do |fd, buffer, nbytes, flags, addr, addr_len, timeout|
              Platforms::Functions.recvfrom(fd, buffer, nbytes, flags, addr, addr_len)
            end
          end

          def selector_update(poller:)
            super

            poller.register_read(fd: @kwargs[:fd], request: self)
          end
        end

        class Write < BaseNonblocking
          def call
            execute do |fd, buffer, nbytes, timeout|
              Platforms::Functions.write(fd, buffer, nbytes)
            end
          end

          def selector_update(poller:)
            super

            poller.register_write(fd: @kwargs[:fd], request: self)
          end
        end

        class PWrite < BaseNonblocking
          def call
            execute do |fd, buffer, nbytes, offset, timeout|
              Platforms::Functions.pwrite(fd, buffer, nbytes, offset)
            end
          end

          def selector_update(poller:)
            super

            poller.register_write(fd: @kwargs[:fd], request: self)
          end
        end

        class Send < BaseNonblocking
          def call
            execute do |fd, buffer, nbytes, flags, timeout|
              Platforms::Functions.send(fd, buffer, nbytes, flags)
            end
          end

          def selector_update(poller:)
            super

            poller.register_write(fd: @kwargs[:fd], request: self)
          end
        end

        class Sendto < BaseNonblocking
          def call
            execute do |fd, buffer, nbytes, flags, addr, addr_len, timeout|
              Platforms::Functions.sendto(fd, buffer, nbytes, flags, addr, addr_len)
            end
          end

          def selector_update(poller:)
            super

            poller.register_write(fd: @kwargs[:fd], request: self)
          end
        end

        class Timer < BaseNonblocking
          def call
            execute do |duration|
              duration = duration.first / 1_000.0
              {
                actual_duration: (Time.now.to_f - @creation.to_f),
                duration: duration
              }
            end
          end

          def selector_update(poller:)
            super

            poller.register_timer(duration: @kwargs[:duration], request: self)
          end
        end

        # Deprecated in favor of the BaseCommand structure and its subclasses.
        # Keep around until clear we don't need this any more and then delete.
        class Command
          attr_accessor :sequence_no
          attr_reader :fiber

          def initialize(fiber:, &blk)
            @fiber = fiber
            @blk = blk
          end

          def reply_to_mailbox(mailbox)
            @mailbox = mailbox
          end

          def finish_setup
            # mailbox refers to originating fiber scheduler's mailbox
            @promise = Promise.new(mailbox: @mailbox)
            @command = Proc.new do
              reply = @blk.call(@fiber)
              Logger.debug(klass: self.class, name: 'command wrapper', message: "reply #{reply.inspect}")
              @promise.fulfill(reply)
            end
          end

          # Executed from the IO worker pool. Reply is sent directly to Fiber
          # Scheduler mailbox.
          def call
            @command.call
          end

          def selector_update(poller:)
            # no op by default
          end
        end

        class BlockingCommand < Command
          def blocking?; true; end
        end

        class NonblockingCommand < Command
          def initialize(fiber:, fd:, &blk)
            @fd = fd
            super(fiber: fiber, &blk)
          end

          def blocking?; false; end
        end

        class NonblockingReadCommand < NonblockingCommand
          def selector_update(poller:)
            super

            # tell, don't ask
            poller.register_read(fd: @fd, request: @command)
          end
        end

        class NonblockingWriteCommand < NonblockingCommand
          def selector_update(poller:)
            super

            poller.register_write(fd: @fd, request: @command)
          end
        end

        class NonblockingTimerCommand < NonblockingCommand
          def initialize(fiber:, duration:, &blk)
            @fd = nil
            @duration = duration
            super(fiber: fiber, fd: nil, &blk)
          end

          def selector_update(poller:)
            super

            poller.register_timer(duration: @duration, request: @command)
          end
        end

        # Basic Request struct. Tracks the requesting Fiber, request number,
        # any associated command timeout, and the command struct. The
        # +command+ can be either a Request::Command or a Request::System message.
        Req = Struct.new(:fiber, :fiber_id, :sequence_no, :timeout, :command)

        # We have two categories of Request messages we can produce.
        # The first category are System messages. These are sent to
        # the IOLoop to do some kind of maintenance task. For example,
        # a newly created Thread creates its own IOFiber and needs to
        # attach to the system-wide IOLoop; it can do so via SystemRegister
        # request. These are fire-and-forget messages so no reply is
        # expected.
        #
        # Secondly, we have the IO commands that need to be represented
        # as Commands. For example, to open a file we send Command::Open
        # request. These are oftentimes expecting a reply.
        #
        module System
          Register = Struct.new(:fiber_id, :outbox)
          Deregister = Struct.new(:fiber_id)
        end

        class Block
          attr_reader :originator, :block

          def initialize(originator:, block:)
            @originator = originator
            @block = block
          end
        end
      end
    end
  end
end
