
class IO
  module Async
    module Private
      module Configure
        class << self
          def setup
            thread_extension
            fiber_extension
            make_io_fiber
          end

          def thread_extension
            return if Thread.current.respond_to?(:local)
            Thread.current.extend(Internal::ThreadLocalMixin)
            Thread.current.local[:_thr_hash] = Thread.current.hash
            Thread.current.local[:_fiber_hash] = Fiber.current.hash
          end

          def fiber_extension
            return if Fiber.current.respond_to?(:local)
            Fiber.current.extend(Internal::FiberLocalMixin)
            Fiber.current.local[:_fiber_hash] = Fiber.current.hash
            Fiber.current.local[:_thr_hash] = Thread.current.hash
          end

          def make_io_fiber
            # One Scheduler per Thread. All fibers created under that Thread
            # share it.
            #
            # This code breaks on JRuby. On JRuby a Fiber is backed by a
            # thread from a pool. So as new fibers swap in the Thread.current
            # could change. This scenario leads to a logical "master thread"
            # having multiple fibers that all think they have a different parent
            # thread, so they all create their own schedulers. Having multiple
            # points of entry/exit for fiber#transfer is impossible to solve
            # (by me anyway).
            return if Thread.current.local.key?(:_scheduler_)
            Logger.debug(klass: self.class, name: :make_io_fiber, message: 'allocating new Fiber Scheduler')
            Thread.current.local[:_scheduler_] = Scheduler.new

            # Completes IO Fiber setup. When it yields, we return
            # to this location and the calling Fiber takes control again
            Thread.current.local[:_scheduler_].complete_setup
          end

          # JRuby only...
          # Thread.current in a Fiber does NOT always return the parent
          # Thread that created the Fiber. As a result, storing locals
          # in Thread.current that can be referenced by the Fiber does
          # not work. In situations where we may be creating a Fiber
          # that will get a different Thread.current reply, we provide
          # this helper method to make sure it is:
          #  1. Provided the correct mixin
          #  2. Initialized with a reference to running Scheduler
          #
          def setup_jruby_thread(scheduler)
            Logger.debug(klass: self.class, name: :setup_jruby_thread, message: 'Extend thread and assign known scheduler')
            thread_extension
            Thread.current.local[:_scheduler_] ||= scheduler
          end
        end
      end
    end
  end
end
