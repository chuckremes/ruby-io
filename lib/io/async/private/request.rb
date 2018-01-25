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
          attr_accessor :sequence_no
          attr_reader :fiber
          def initialize(fiber, **kwargs)
            @fiber = fiber
            @kwargs = kwargs
          end

          def reply_to_mailbox(mailbox)
            @mailbox = mailbox
          end

          def finish_setup
            @promise = Promise.new(mailbox: @mailbox)
          end

          def execute
            results = yield(@kwargs.values)

            results[:fiber] = @fiber
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

        class Fibers
          attr_reader :originator, :spawned

          def initialize(originator:, spawned:)
            @originator = originator
            @spawned = spawned
          end
        end
      end
    end
  end
end
