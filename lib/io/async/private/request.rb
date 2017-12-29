class IO
  module Async
    module Private
      module Request
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
          def register(poller:)
            # tell, don't ask
            poller.register_read(fd: @fd, request: @command)
          end
        end

        class NonblockingWriteCommand < NonblockingCommand
          def register(poller:)
            poller.register_write(fd: @fd, request: @command)
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
        end
      end
    end
  end
end
