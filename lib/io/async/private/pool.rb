class IO
  module Async
    module Private
      class Pool
        def initialize(size: 2)
          @size = size
          @inbox = Mailbox.new
          @threads = Internal::Thread.new do |thr|
            Logger.debug(klass: self.class, name: :new, message: 'launch worker pool thread')              
            loop do
              request = @inbox.pickup(nonblocking: false)
              process(request)
            end
          end
        end

        def dispatch(request)
          @inbox.post(request)
        end

        def process(request)
          # Executes the command (saved as a closure). Any reply is
          # communicated via a Promise directly back to the calling Fiber
          # Scheduler that originated request.
          Logger.debug(klass: self.class, name: :process, message: 'executing command in pool')
          request.call
        end
      end
    end
  end
end
