require 'set'

class IO
  module Async
    module Private
      class Scheduler
        def initialize
          # TODO: Need to consider making one or both of these SizedQueues so we
          # can exert back-pressure on threads that are producing too many
          # IO Requests.
          @outbox = nil # conduit to IOLoop, allocated after fetching IOLoop
          @inbox = Mailbox.new # replies back from IOLoop

          @mapper = Mapper.new
          @known_fibers = Set.new

          @io_fiber = Internal::Fiber.new do |calling_fiber|
            make_io_thread
            io_fiber_loop(calling_fiber)
          end
          @state = :nil
        end

        # Pass the request to the IO Fiber for processing next.
        def enqueue(request)
          @io_fiber.transfer(request)
        end

        def complete_setup
          return unless :nil == @state

          @state = :complete
          @io_fiber.transfer(Fiber.current)
        end

        # Setup a dedicated Thread to handle all incoming Async IO
        # requests. Upon completion of setup, yield back to caller.
        #
        def make_io_thread
          # Another thread may have created a dedicated IO Loop.
          # It's a singleton object, so just ask it for a reference
          # to the current IO Loop
          @io_loop = IOLoop.current
          @outbox = IOLoopMailbox.new(self_pipe: @io_loop.self_pipe_writer)
          @io_loop.register(fiber: Fiber.current, outbox: @outbox)
        end

        # An infinite loop. Upon entering for the first time, we know
        # that all setup is complete. We yield/transfer back to the caller.
        # When any future Fiber makes an IO Request, the Scheduler
        # resumes/transfers the IO Fiber and passes in a Request. That request
        # is submitted to the IO Thread and then we wait for a reply.
        def io_fiber_loop(originating_fiber)
          request = originating_fiber.transfer

          begin
            post(request)
            Logger.debug(klass: self.class, name: :io_fiber_loop, message: 'waiting for reply from inbox')
            reply = @inbox.pickup(nonblocking: false)

            # Pass reply back to Fiber that made request
            request = lookup_reference(reply)
            request = deliver(fiber: request.fiber, reply: reply)
          end while true
        end

        def post(request)
          return unless request.is_a?(Request::Command)

          track_known_fibers(request)
          save_reference(request)
          save_reply_mailbox(request)
          @outbox.post request
        end

        # Return the reply to the fiber. Suspends this fiber right here.
        # When we receive the next IO Request, we will resume (transfer)
        # to here and the return value of #deliver will be the next request.
        def deliver(fiber:, reply:)
          fiber.transfer(reply)
        end

        def save_reference(request)
          @mapper[request.fiber] = request
        end

        def lookup_reference(reply)
          @mapper[reply[:fiber]]
        end

        def save_reply_mailbox(request)
          request.reply_to_mailbox(@inbox)
          request.finish_setup
        end

        def track_known_fibers(request)
          @known_fibers.add(request.fiber)
        end
      end
    end
  end
end
