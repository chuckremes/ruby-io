require_relative 'select'

class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion.
    class SelectPoller
      NO_TIMEOUT = TimeValStruct.new
      SHORT_TIMEOUT = TimeValStruct.new.tap { |ts| ts[:tv_usec] = 1 }
      SELF_PIPE_READ_SIZE = 20

      def initialize(self_pipe:)
        @read_master_set   = FDSetStruct.new
        @read_working_set  = FDSetStruct.new
        @write_master_set  = FDSetStruct.new
        @write_working_set = FDSetStruct.new

        @read_callbacks = {}
        @write_callbacks = {}
        @timeval = TimeValStruct.new
        @timers = Common::Timers.new
        
        self_pipe_setup(self_pipe)
        Logger.debug(klass: self.class, name: 'select poller', message: 'poller allocated!')
      end

      def max_allowed
        Constants::FDSET_SIZE
      end

      def register_timer(duration:, request:)
        @timers.add_oneshot(delay: duration, callback: request)
      end

      def register_read(fd:, request:)
        @read_callbacks[fd] = request
        @read_master_set.set(fd: fd)

        Logger.debug(klass: self.class, name: 'select poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        @write_callbacks[fd] = request
        @write_master_set.set(fd: fd)

        Logger.debug(klass: self.class, name: 'select poller', message: "registered for write, fd [#{fd}]")
      end

      # Dispatches the registered reads and writes to +select+.
      def poll
        Logger.debug(klass: self.class, name: 'select poller', message: 'calling select')
        # Copy FDs from master to working set if there are any; else set local working set
        # to nil so select(2) ignores it. Saves on reallocating working_set every loop.
        read_working_set = @read_master_set.max_fd >= 0 ? @read_master_set.copy_to(copy: @read_working_set) : nil
        write_working_set = @write_master_set.max_fd >= 0 ? @write_master_set.copy_to(copy: @write_working_set) : nil

        max_fd = [@read_master_set.max_fd, @write_master_set.max_fd].max

        rc = Platforms.select(max_fd + 1, read_working_set, write_working_set, nil, shortest_timeout)
        Logger.debug(klass: self.class, name: 'select poller', message: "select returned [#{rc}] events!")

        if rc >= 0
          process_events(
            count: rc,
            working_set: read_working_set,
            master_set: @read_master_set,
            callbacks: @read_callbacks,
            kind: 'READ'
          )

          process_events(
            count: rc,
            working_set: write_working_set,
            master_set: @write_master_set,
            callbacks: @write_callbacks,
            kind: 'WRITE'
          )

          @timers.fire_expired
        else
          Logger.debug(klass: self.class, name: 'select poller', message: "rc [#{rc}], errno [#{::FFI.errno}]")
        end
      end

      private

      def process_events(count:, working_set:, master_set:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: 'select poller', message: "max_fd [#{master_set.max_fd}]")
        return if master_set.max_fd < 0

        master_set.each do |fd|
          break if 0 == count
          if working_set.set?(fd: fd)
            master_set.clear(fd: fd)
            execute_callback(identity: fd, callbacks: callbacks, kind: kind)
            count -= 1
          end
        end
      end

      def execute_callback(identity:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: 'select poller', message: "execute [#{kind}] callback for fd [#{identity}]")

        request = callbacks.delete(identity)
        if request
          request == :self_pipe ? self_pipe_read : request.call
        else
          raise "Got [#{kind}] event for fd [#{identity}] with no registered callback"
        end
      end

      # Calculate the shortest timeout based upon the timer nearest to firing.
      # Returns a TimeVal struct.
      #
      # If no timers exist, then this would return a zero timespec which could
      # lead to a busy loop. Enforce some minimum sleep time of around 50ms.
      #
      def shortest_timeout
        delay_ms = @timers.wait_interval.to_i

        delay_ms = 50 if delay_ms.zero?

        # convert to seconds and microseconds
        seconds = delay_ms / 1_000
        microseconds = (delay_ms % 1_000) * 1_000

        @timeval[:tv_sec] = seconds
        @timeval[:tv_usec] = microseconds
        @timeval
      end

      def self_pipe_read
        Logger.debug(klass: self.class, name: 'kqueue poller', message: 'self-pipe awakened sleeping selector')
        # ignore read errors
        begin
          reply = Platforms::Functions.read(@self_pipe, @self_pipe_buffer, SELF_PIPE_READ_SIZE)
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
    end

    class Poller < SelectPoller
    end
  end
end
