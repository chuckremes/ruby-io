class IO
  module Async
    module Private
      class Pool
        def initialize(size: 2)
          @size = size
          @inbox = Mailbox.new
          @threads = []
          @size.times do |i|
            Internal::Thread.new do |thr|
              Logger.debug(klass: self.class, name: :new, message: "launch worker pool thread-#{i}")
              loop do
                request = @inbox.pickup(nonblocking: false)
                process(request: request, index: i)
              end
            end
          end
        end

        def dispatch(request)
          @inbox.post(request)
        end

        def process(request:, index:)
          # Executes the command (saved as a closure). Any reply is
          # communicated via a Promise directly back to the calling Fiber
          # Scheduler that originated request.
          Logger.debug(klass: self.class, name: :process, message: "executing command in pool thread-#{index}")
          value, secs = elapsed { request.call }
          Logger.debug(klass: self.class, name: :process, message: "executed command in pool thread-#{index}")
          Logger.debug(klass: self.class, name: :process, message: "[#{secs}] secs for execution in pool thread-#{index}")
          value
        end

        def elapsed
          start = Time.now
          value = yield
          secs = Time.now - start
          [value, secs]
        end
      end
    end
  end
end
