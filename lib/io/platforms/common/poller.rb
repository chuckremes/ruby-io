class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion.
    #
    # ---------
    # Likely to be subclassed for each platform. This class only contains the common
    # functions, so it will never be instantiated directly.
    #
    class Poller
      SELF_PIPE_READ_SIZE = 20
      EMPTY_CALLBACK = Proc.new { nil }

      def initialize(self_pipe:)
        @change_count = 0
        @read_callbacks = {}
        @write_callbacks = {}
        @timers = Common::Timers.new
        self_pipe_setup(self_pipe)

        Logger.debug(klass: self.class, name: :super_initialize, message: 'allocating poller')
      end

      def will_accept_more_events?
        @change_count < max_allowed - 1
      end

      # Called to remove the +fd+ from the poller and delete any callbacks
      def deregister(fd:)
        delete_from_selector(fd: fd)
        delete_callbacks(fd: fd)
      end

      def register_timer(duration:, request:)
        @timers.add_oneshot(delay: duration, callback: request)
      end

      def register_read(fd:, request:)
        @read_callbacks[fd] = request

        Logger.debug(klass: self.class, name: :register_read, message: "registered read callback, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        @write_callbacks[fd] = request

        Logger.debug(klass: self.class, name: :register_write, message: "registered write callback, fd [#{fd}]")
      end


      private

      def process_error(event:)
        Logger.debug(klass: self.class, name: :process_error, message: "event #{event.inspect}")
      end

      def execute_callback(event:, identity:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: :execute_callback, message: "execute [#{kind}] callback for fd [#{identity}]")

        request = callbacks.delete(identity)
        if request
          request == :self_pipe ? self_pipe_read : request.call
        else
          raise "Got [#{kind}] event for fd [#{identity}] with no registered callback"
        end
      end

      # Calculate the shortest timeout based upon the timer nearest to firing.
      # Returns the struct type expected by the specific poller.
      #
      # If no timers exist, then this would return a zeroed struct which could
      # lead to a busy loop. Enforce some minimum sleep time of around 50ms.
      #
      def shortest_timeout
        delay_ms = @timers.wait_interval.to_i
        delay_ms = 50 if delay_ms.zero?
        make_timeout_struct(delay_ms)
      end

      def self_pipe_read
        Logger.debug(klass: self.class, name: 'poller', message: 'self-pipe awakened sleeping selector')
        # ignore read errors
        begin
          reply = POSIX.read(@self_pipe, @self_pipe_buffer, SELF_PIPE_READ_SIZE)
          rc = reply[:rc]
        end until rc.zero? || rc == -1 || rc < SELF_PIPE_READ_SIZE
        # necessary to reregister since everything is setup for ONESHOT
        register_read(fd: @self_pipe, request: :self_pipe)
      end

      def self_pipe_setup(self_pipe)
        @self_pipe = self_pipe
        @self_pipe_buffer = ::FFI::MemoryPointer.new(:int, SELF_PIPE_READ_SIZE)
        register_read(fd: @self_pipe, request: :self_pipe)
      end

      def delete_callbacks(fd:)
        @read_callbacks[fd] = EMPTY_CALLBACK if @read_callbacks.key?(fd)
        @write_callbacks[fd] = EMPTY_CALLBACK if @write_callbacks.key?(fd)
      end
    end
  end
end
