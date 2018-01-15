class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion. It maintains it's change_count internally
    # so parallel calls would likely corrupt the changelist.
    class KqueuePoller
      MAX_EVENTS = 10
      NO_TIMEOUT = TimeSpecStruct.new
      SHORT_TIMEOUT = TimeSpecStruct.new.tap { |ts| ts[:tv_sec] = 1 }
      SELF_PIPE_READ_SIZE = 20
      EMPTY_CALLBACK = Proc.new { nil }

      def initialize(self_pipe:)
        @kq_fd = Platforms.kqueue

        # fatal error if we can't allocate the kqueue
        raise "Fatal error, kqueue failed to allocate, rc [#{@kq_fd}], errno [#{::FFI.errno}]" if @kq_fd < 0

        @events_memory = ::FFI::MemoryPointer.new(Platforms::KEventStruct, MAX_EVENTS)
        @events = MAX_EVENTS.times.to_a.map do |index|
          Platforms::KEventStruct.new(@events_memory + index * Platforms::KEventStruct.size)
        end
        @change_count = 0
        @read_callbacks = {}
        @write_callbacks = {}
        @timers = Common::Timers.new
        @timespec = TimeSpecStruct.new

        self_pipe_setup(self_pipe)
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered self-pipe for read [#{@self_pipe}]")
        Logger.debug(klass: self.class, name: 'kqueue poller', message: 'kqueue allocated!')
      end

      def max_allowed
        MAX_EVENTS
      end

      # Called to remove the +fd+ from the poller and delete any callbacks
      def deregister(fd:)
        delete_from_selector(fd: fd)
        delete_callbacks(fd: fd)
      end

      def register_timer(duration:, request:)
        timer = @timers.add_oneshot(delay: duration, callback: request)
        register(
          fd: 1,
          request: request,
          filter: Constants::EVFILT_TIMER,
          flags: Constants::EV_ADD | Constants::EV_ENABLE | Constants::EV_ONESHOT,
          fflags: Constants::NOTE_MSECONDS,
          data: duration,
          udata: timer.object_id
        )
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered for timer, object_id [#{request.object_id}]")
      end

      def register_read(fd:, request:)
        @read_callbacks[fd] = request
        register(
          fd: fd,
          request: request,
          filter: Constants::EVFILT_READ,
          flags: Constants::EV_ADD | Constants::EV_ENABLE | Constants::EV_ONESHOT
        )
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        @write_callbacks[fd] = request
        register(
          fd: fd,
          request: request,
          filter: Constants::EVFILT_WRITE,
          flags: Constants::EV_ADD | Constants::EV_ENABLE | Constants::EV_ONESHOT
        )
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered for write, fd [#{fd}]")
      end

      # Dispatches the registered reads and writes to +kevent+. We can queue up to MAX_EVENTS
      # in the changelist before we flush to +kevent+.
      def poll
        Logger.debug(klass: self.class, name: 'kqueue poller', message: 'calling kevent')
        rc = Platforms.kevent(@kq_fd, @events[0], @change_count, @events[0], MAX_EVENTS, shortest_timeout)
        @change_count = 0
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "kevent returned [#{rc}] events!")

        if rc >= 0
          rc.times { |index| process_event(event: @events[index]) }
        else
          Logger.debug(klass: self.class, name: 'kqueue poller', message: "rc [#{rc}], errno [#{::FFI.errno}]")
        end
      end

      private

      def process_event(event:)
        if error?(event)
          process_error(event: event)
        elsif event.filter == Constants::EVFILT_READ
          process_read_event(event: event)
        elsif event.filter == Constants::EVFILT_WRITE
          process_write_event(event: event)
        elsif event.filter == Constants::EVFILT_TIMER
          process_timer_event(event: event)
        else
          raise "Fatal: unknown event flag [#{event.flags}]"
        end
      end

      def process_error(event:)
        Logger.debug(klass: self.class, name: :process_error, message: "event #{event.inspect}")
      end

      def process_read_event(event:)
        execute_callback(event: event, identity: event.ident, callbacks: @read_callbacks, kind: 'READ')
      end

      def process_write_event(event:)
        execute_callback(event: event, identity: event.ident, callbacks: @write_callbacks, kind: 'WRITE')
      end

      def process_timer_event(event:)
        @timers.fire_expired
      end

      def execute_callback(event:, identity:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "execute [#{kind}] callback for fd [#{identity}]")

        request = callbacks.delete(identity)
        if request
          request == :self_pipe ? self_pipe_read : request.call
        else
          raise "Got [#{kind}] event for fd [#{identity}] with no registered callback"
        end
      end

      def register(fd:, request:, filter:, flags:, fflags: 0, data: 0, udata: 0)
        event = @events[@change_count]
        event.ev_set(
          ident: fd,
          filter: filter,
          flags: flags,
          fflags: fflags,
          data: data,
          udata: udata
        )

        @change_count += 1
      end

      def shortest_timeout
        delay_ms = @timers.wait_interval.to_i

        delay_ms = 50 if delay_ms.zero?

        # convert to local units
        seconds = delay_ms / 1_000
        nanoseconds = (delay_ms % 1_000) * 1_000_000

        @timespec[:tv_sec] = seconds
        @timespec[:tv_nsec] = nanoseconds
        @timespec
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

      # Due to the vagaries of the blocking +close+ function being called by the worker
      # pool, the +fd+ might already be deleted from the kqueue. If it is already gone,
      # then we'll get an EV_ERROR on the next poll. If it's not gone, this will clean
      # it up.
      def delete_from_selector(fd:)
        register(
          fd: fd,
          request: nil,
          filter: Constants::EVFILT_READ,
          flags: Constants::EV_DELETE
        )

        register(
          fd: fd,
          request: nil,
          filter: Constants::EVFILT_WRITE,
          flags: Constants::EV_DELETE
        )
        Logger.debug(klass: self.class, name: :delete_from_selector, message: "deleting, fd [#{fd}]")
      end

      def delete_callbacks(fd:)
        @read_callbacks[fd] = EMPTY_CALLBACK if @read_callbacks.key?(fd)
        @write_callbacks[fd] = EMPTY_CALLBACK if @write_callbacks.key?(fd)
      end

      def error?(event)
        (event.flags & Constants::EV_ERROR) > 0
      end
    end

    class Poller < KqueuePoller
    end
  end
end
