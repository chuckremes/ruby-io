require 'set'

SCHED_DEBUG = true

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
          @runnables = []

          @io_fiber = Internal::Fiber.new do |calling_fiber|
            @alive = true
            Logger.debug(klass: self.class, name: :io_fiber, message: 'Starting IO Fiber...')
            make_io_thread
            io_fiber_loop(calling_fiber)
          end
          @state = :nil
          #          ObjectSpace.define_finalizer(self, self.class.finalize(@io_loop, @io_fiber, @outbox))
        end

        #        def self.finalize(ioloop, iofiber, mailbox)
        #          Proc.new do |id|
        #            puts "#{tid}, Scheduler#io_fiber_loop, finalizer running, deregistering from IOLoop"
        #            ioloop.deregister(fiber: iofiber)
        #            mailbox = nil
        #          end
        #        end

        def finalize_loop
          Logger.debug(klass: self.class, name: :finalize_loop, message: 'Finalizing IO Fiber loop...')
          @alive = false
          reschedule_me
        end

        def schedule_request(request)
          Logger.debug(klass: self.class, name: :schedule_request, message: "[#{tid}], from [#{fid}] to [#{@io_fiber.fid}]")
          val = enqueue(request)
          Logger.debug(klass: self.class, name: :schedule_request, message: "[#{tid}], into [#{fid}], val #{val.inspect}")
          val
        end

        def schedule_fibers(originator:, spawned:)
          raise 'Argument must be a Fiber!' unless originator.is_a?(Fiber)
          raise 'Spawned arg must be a Proc!' unless spawned.is_a?(Proc)
          Logger.debug(klass: self.class, name: :schedule_fibers, message: "[#{tid}], from [#{fid}] to [#{@io_fiber.fid}] with spawn block")
          val = enqueue(Request::Fibers.new(originator: originator, spawned: spawned))
          raise "Value from #schedule_fibers should be nil but is non-nil! #{val.inspect}" if val
          val
        end

        def reschedule_me
          enqueue(nil)
        end

        # Pass the request to the IO Fiber for processing next.
        def enqueue(request)
          @io_fiber.transfer(request) if @io_fiber.alive?
        end

        def complete_setup
          return unless :nil == @state

          @state = :complete
          @io_fiber.transfer(Fiber.current)
          Logger.debug(klass: self.class, name: :complete_setup, message: "[#{tid}], into [#{fid}]")
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
        def io_fiber_loop(calling_fiber)
          request = calling_fiber.transfer
          setup_thread
          post(request)

          begin
            process_runnables
            process_replies
          end while @alive

          Logger.debug(klass: self.class, name: :io_fiber_loop, message: "[#{tid}], deregistering from IOLoop")
          @io_loop.deregister(fiber: Fiber.current)
          @outbox = nil
        end

        def post(request)
          return unless request.is_a?(Request::Command) || request.is_a?(Request::BaseBlocking)

          save_reference(request)
          save_reply_mailbox(request)
          @outbox.post(request)
        end

        def add_runnable(runnable)
          Logger.debug(klass: self.class, name: :add_runnable, message: "[#{tid}]")
          @runnables.unshift(runnable) if runnable
        end

        def pop_runnable
          @runnables.pop
        end

        def process_runnables
          while runnable = pop_runnable
            fiber, argument = if runnable.is_a?(Response::Wrapper)
              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], processing a reply")

              # lookup originator
              request = lookup_reference(runnable.object)
              [request.fiber, runnable.object]
            elsif runnable.is_a?(Fiber)
              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], processing fiber [#{runnable.fid}]")
              [runnable, nil]
            elsif runnable.is_a?(Proc)
              # wrap this in a fiber, add it to runnables, and restart this loop
              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], got block to make runnable")
              f = make_runnable_from_proc(runnable)
              add_runnable(f)

              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], restart loop from midway")
              next # start loop from top
              [nil, nil] # will never get here, but satisfies the compiler
            end

            # transfer to the fiber and pass correct argument
            # iofiber suspends here; when it is transferred back we
            # expect a Request::Command. anything else is likely the
            # return value of an exited fiber.
            Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], from [#{fid}] to [#{fiber.fid}]")
            object = fiber.transfer(argument)
            setup_thread
            Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], into [#{fid}]")

            if object.is_a?(Request::Command) || object.is_a?(Request::BaseBlocking)
              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], handed off command request")
              post(object)
            elsif object.is_a?(Request::Fibers)
              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], handed off fiber")
              add_runnable(object.spawned)
              add_runnable(object.originator)
            elsif object.nil?
              Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], handed off nil, ignore!")
            else
              raise "Do not understand this object, class #{object.class}, #{object.inspect}"
            end
          end
        end

        def process_replies
          return unless @alive

          Logger.debug(klass: self.class, name: :process_replies, message: 'waiting for reply from inbox')
          reply = @inbox.pickup(nonblocking: false)

          raise 'Unexpectedly received a nil reply from IOLoop!' unless reply
          Logger.debug(klass: self.class, name: :process_replies, message: "[#{tid}], got reply to deliver, #{reply.inspect}")
          add_runnable(Response::Wrapper.new(reply))
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

        def make_runnable_from_proc(block)
          # Had to push this to its own method. When it was part of #process_runnables
          # it was confusing the +block+ variable in the closure and marking it as a Fiber.
          # Oops. Moving here solved that closure capture issue.
          Fiber.new do
            block.call
            Logger.debug(klass: self.class, name: :make_runnable_from_proc, message: "[#{tid}], fiber exiting, see where we transfer to")
          end
        end

        if RUBY_PLATFORM =~ /java/
          # JRuby uses a thread pool for Fibers, so a Fiber may run on many different threads
          # over the course of its life. We need to add our extensions if they are missing.
          def setup_thread
            Thread.current.extend(Internal::ThreadLocalMixin) unless Thread.current.respond_to?(:local)
          end
        else
          def setup_thread(); end
        end
      end
    end
  end
end
