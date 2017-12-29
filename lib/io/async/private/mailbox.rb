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
    end
  end
end
