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

      def initialize
        @kq_fd = Platforms.kqueue

        # fatal error if we can't allocate the kqueue
        raise "Fatal error, kqueue failed to allocate, rc [#{@kq_fd}], errno [#{FFI.errno}]" if @kq_fd < 0

        @events_memory = FFI::MemoryPointer.new(Platforms::KEventStruct, MAX_EVENTS)
        @events = MAX_EVENTS.times.to_a.map do |index|
          Platforms::KEventStruct.new(@events_memory + index * Platforms::KEventStruct.size)
        end
        @change_count = 0
        @read_callbacks = {}
        @write_callbacks = {}
        Logger.debug(klass: self.class, name: 'kqueue poller', message: 'kqueue allocated!')
      end

      def max_allowed
        MAX_EVENTS
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
        rc = Platforms.kevent(@kq_fd, @events[0], @change_count, @events[0], MAX_EVENTS, SHORT_TIMEOUT)
        @change_count = 0
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "kevent returned [#{rc}] events!")

        if rc >= 0
          rc.times { |index| process_event(event: @events[index]) }
        else
          Logger.debug(klass: self.class, name: 'kqueue poller', message: "rc [#{rc}], errno [#{FFI.errno}]")
        end
      end

      private

      def process_event(event:)
        if event.filter == Constants::EVFILT_READ
          process_read_event(event: event)
        elsif event.filter == Constants::EVFILT_WRITE
          process_write_event(event: event)
        elsif event.filter == Constants::EVFILT_TIMER
        else
          raise "Fatal: unknown event flag [#{event.flags}]"
        end
      end

      def process_read_event(event:)
        execute_callback(event: event, callbacks: @read_callbacks, kind: 'READ')
      end

      def process_write_event(event:)
        execute_callback(event: event, callbacks: @write_callbacks, kind: 'WRITE')
      end

      def execute_callback(event:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "execute [#{kind}] callback for fd [#{event.ident}]")
        p event
        block = callbacks.delete(event.ident)
        if block
          block.call
        else
          raise "Got [#{kind}] event for fd [#{event.ident}] with no registered callback"
        end
      end

      def register(fd:, request:, filter:, flags:)
        event = @events[@change_count]
        event.ev_set(
          ident: fd,
          filter: filter,
          flags: flags,
          fflags: 0,
          data: 0,
          udata: nil
        )
        @change_count += 1
      end
    end

    class Poller < KqueuePoller
    end
  end
end
