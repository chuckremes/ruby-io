class IO
  module Async
    module Private
      class Mailbox
        def initialize
          @queue = Queue.new
        end

        def post(message)
          @queue << message
        end

        def pickup(nonblocking: true)
          request = nil
          begin
            request = @queue.pop(nonblocking)
          rescue ThreadError
          end
          request
        end
      end

      # Takes a pipe file descriptor as an argument. Whenever
      # a message is posted to the mailbox, we also do a non-blocking
      # write to the pipe. The read end of this pipe should be part
      # of the Poller set and will wake up the selector if it's
      # sleeping.
      #
      class IOLoopMailbox < Mailbox
        def initialize(self_pipe:)
          super()
          @pipe_fd = self_pipe
          @buffer = ::FFI::MemoryPointer.new(1)
          @buffer.put_bytes(0, '.', 0, 1)
        end

        def post(message)
          super

          # ignore errors
          rc = POSIX.write(@pipe_fd, @buffer, 1)
          Logger.debug(klass: self.class, name: 'post', message: "wrote to pipe [#{@pipe_fd}], rc #{rc.inspect}")
        end
      end
    end
  end
end
