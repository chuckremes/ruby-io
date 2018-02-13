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
          @outstanding_posts = 0
          @_thr_hash = Thread.current.hash
          Thread.current.local[:name] = Thread.current.local[:name].to_s + '-' + 'SCHED'

          @io_fiber = Internal::Fiber.new do |calling_fiber|
            @alive = true
            Logger.debug(klass: self.class, name: :io_fiber, message: 'Starting IO Fiber...')
            make_io_thread
            io_fiber_loop(calling_fiber)
          end
          @_fiber_hash = @io_fiber.hash
          @fid = "#{@_thr_hash}-#{@_fiber_hash}-SCHED"
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
          Logger.debug(klass: self.class, name: :schedule_request, message: "[#{tid}], from [#{@fid} / #{@io_fiber.hash}] to [SCHED-#{@io_fiber.hash}]")
          val = enqueue(request)
          Logger.debug(klass: self.class, name: :schedule_request, message: "[#{tid}], into [#{@fid} / #{@io_fiber.hash}], val #{val.inspect}")
          val
        end

        def schedule_block(originator:, block:)
          raise '+block+ arg must be a Proc!' unless block.is_a?(Proc)
          Logger.debug(klass: self.class, name: :schedule_block, message: "[#{tid}], from [#{fid}] to scheduler [#{@io_fiber.hash}] with spawn block")
          val = enqueue(Request::Block.new(originator: originator, block: block))
          raise "Value from #schedule_block should be nil but is non-nil! #{val.inspect}" if val
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
          Logger.debug(klass: self.class, name: :complete_setup, message: "[#{tid}], into [#{@fid}]")
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
          categorize_request(request) # prime the pump with a runnable!

          begin
            process_runnables
            process_replies
          end while @alive

          Logger.debug(klass: self.class, name: :io_fiber_loop, message: "[#{tid}], deregistering from IOLoop")
          @io_loop.deregister(fiber: Fiber.current)
          @outbox = nil
        end

        def post(request)
          return unless command?(request)

          save_reference(request)
          save_reply_mailbox(request)
          @outstanding_posts += 1
          Logger.debug(klass: self.class, name: :post_request, message: "[#{tid}], posting request, [#{@outstanding_posts}] outstanding, seqno [#{request.sequence_no}]")
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
            fiber, argument = unwrap(runnable)

            # transfer to the fiber and pass correct argument
            # iofiber suspends here; when it is transferred back we
            # expect command? to be true. anything else is likely the
            # return value of an exited fiber.
            Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], from [#{@fid} / #{Fiber.current.hash}] to [#{fiber.hash}]")
            start_transfer = Time.now
            object = fiber.transfer(argument)
            secs = Time.now - start_transfer
            Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], [#{secs}] spent in transferred fiber [#{fiber.hash}]")
            setup_thread
            Logger.debug(klass: self.class, name: :process_runnables, message: "[#{tid}], into [#{@fid} / #{Fiber.current.hash}]")

            categorize_request(object)
          end
        end

        def process_replies
          return unless @alive

          Logger.debug(klass: self.class, name: :process_replies, message: "[#{tid}], will suspend for reply from inbox, [#{@runnables.size}] runnables")
          start_waiting = Time.now
          reply = @inbox.pickup(nonblocking: false)
          @outstanding_posts -= 1
          Logger.debug(klass: self.class, name: :process_replies, message: "[#{tid}], [#{Time.now - start_waiting}] secs suspended! [#{@outstanding_posts}] outstanding")

          raise 'Unexpectedly received a nil reply from IOLoop!' unless reply
          Logger.debug(klass: self.class, name: :process_replies, message: "[#{tid}], got reply to deliver, #{reply.inspect}")
          add_runnable(Response::Wrapper.new(reply))
        end

        def save_reference(request)
          @mapper[request.fiber] = request
        end

        def lookup_reference(reply)
          @mapper.delete(reply[:fiber])
        end

        def save_reply_mailbox(request)
          request.reply_to_mailbox(@inbox)
          request.finish_setup
        end

        def unwrap(runnable)
          if runnable.is_a?(Response::Wrapper)
            # lookup originator
            request = lookup_reference(runnable.object)
            Logger.debug(klass: self.class, name: :unwrap, message: "[#{tid}], processing a reply, sequence_no [#{request.sequence_no}]")
            [request.fiber, runnable.object]

          elsif runnable.is_a?(Fiber)
            Logger.debug(klass: self.class, name: :unwrap, message: "[#{tid}], rescheduled fiber [#{runnable.hash}], #{runnable.inspect}")
            [runnable, nil]
          end
        end

        def categorize_request(object)
          if command?(object)
            Logger.debug(klass: self.class, name: :categorize_request, message: "[#{tid}], handed off command request")
            post(object)
          elsif object.is_a?(Request::Block)
            Logger.debug(klass: self.class, name: :categorize_request, message: "[#{tid}], handed off fiber and block")
            add_runnable(object.originator)
            add_runnable(make_runnable_from_proc(object.block))
          elsif object.nil?
            Logger.debug(klass: self.class, name: :categorize_request, message: "[#{tid}], handed off nil, ignore!")
          else
            raise "Do not understand this object, class #{object.class}, #{object.inspect}"
          end
        end

        def make_runnable_from_proc(block)
          scheduler = self
          # Had to push this to its own method. When it was part of #process_runnables
          # it was confusing the +block+ variable in the closure and marking it as a Fiber.
          # Oops. Moving here solved that closure capture issue.
          Internal::Fiber.new do
            unless Thread.current.respond_to?(:local)
              IO::Async::Private::Configure.setup_jruby_thread(scheduler)
            end

            block.call
            Logger.debug(klass: self.class, name: :make_runnable_from_proc, message: "[#{tid}], fiber exiting, see where we transfer to")
          end
        end

        def command?(request)
          request.is_a?(Request::Command) || request.is_a?(Request::BaseCommand)
        end

        if RUBY_PLATFORM =~ /java/
          # JRuby uses a thread pool for Fibers, so a Fiber may run on many different threads
          # over the course of its life. We need to add our extensions if they are missing.
          def setup_thread
            unless Thread.current.respond_to?(:local)
              thr_hash = Thread.current.hash
              fiber_hash = Fiber.current.hash
              Logger.debug(klass: self.class, name: :setup_thread, message: "current thread needs mixin!")
              Logger.debug(klass: self.class, name: :setup_thread, message: "thread, creator [#{@_thr_hash}], now [#{thr_hash}]")
              Logger.debug(klass: self.class, name: :setup_thread, message: "fiber , creator [#{@_fiber_hash}], now [#{fiber_hash}]")
              Thread.current.extend(Internal::ThreadLocalMixin)
              Thread.current.local[:name] = "SCHEDPOOL-#{@_thr_hash}"
            end
          end
        else
          def setup_thread(); end
        end
      end
    end
  end
end
