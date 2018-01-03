
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
            Thread.current.extend(Internal::LocalMixin)
            raise "extension failed" unless Thread.current.respond_to?(:local)
          end

          def fiber_extension
            return if Fiber.current.respond_to?(:local)
            Fiber.current.extend(Internal::LocalMixin)
            raise "extension failed" unless Fiber.current.respond_to?(:local)
            Fiber.current.local[:sequence_no] = -1
          end

          def make_io_fiber
            return if Thread.current.local.key?(:_scheduler_)
            Thread.current.local[:_scheduler_] = Scheduler.new

            # Completes IO Fiber setup. When it yields, we return
            # to this location and the calling Fiber takes control again
            Thread.current.local[:_scheduler_].complete_setup
          end
        end
      end
    end
  end
end
