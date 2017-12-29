require_relative 'configure/setup'
require_relative 'promise'
require_relative 'pool'
require_relative 'request'
require_relative 'mailbox'
require_relative 'mapper'
require_relative 'io_loop'
require_relative 'scheduler'

class IO
  module Async
    module Private
      class << self
        #
        # Helpers for building the asynchronous requests
        #

        def build_blocking_request
          request = Request::BlockingCommand.new(fiber: Fiber.current) do |fiber|
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
