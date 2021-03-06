require_relative '../common/poller'

class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion. It maintains its change_count internally
    # so parallel calls would likely corrupt the changelist.
    class KqueuePoller < Poller
      MAX_EVENTS = 25

      def initialize(self_pipe:)
        @kq_fd = Platforms::Functions.kqueue

        # fatal error if we can't allocate the kqueue
        raise "Fatal error, kqueue failed to allocate, rc [#{@kq_fd}], errno [#{::FFI.errno}]" if @kq_fd < 0

        @events_memory = ::FFI::MemoryPointer.new(Platforms::Structs::KEventStruct, MAX_EVENTS)
        @events = MAX_EVENTS.times.to_a.map do |index|
          Platforms::Structs::KEventStruct.new(@events_memory + index * Platforms::Structs::KEventStruct.size)
        end
        @timespec = Structs::TimeSpecStruct.new

        super
        Logger.debug(klass: self.class, name: 'kqueue poller', message: 'kqueue allocated!')
      end

      def max_allowed
        MAX_EVENTS
      end

      def register_timer(duration:, request:)
        timer = super

        register(
          fd: timer.hash,
          request: request,
          filter: Constants::EVFILT_TIMER,
          flags: Constants::EV_ADD | Constants::EV_ENABLE | Constants::EV_ONESHOT,
          fflags: Constants::NOTE_MSECONDS,
          data: duration
        )
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered for timer duration [#{duration}], object_id [#{request.object_id}]")
      end

      def register_read(fd:, request:)
        super

        register(
          fd: fd,
          request: request,
          filter: Constants::EVFILT_READ,
          flags: Constants::EV_ADD | Constants::EV_ENABLE | Constants::EV_ONESHOT
        )
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        super

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
        rc = Platforms::Functions.kevent(@kq_fd, @events[0], @change_count, @events[0], MAX_EVENTS, shortest_timeout)
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

      def process_read_event(event:)
        Logger.debug(klass: self.class, name: :process_read_event, message: '')
        execute_callback(event: event, identity: event.ident, callbacks: @read_callbacks, kind: 'READ')
      end

      def process_write_event(event:)
        Logger.debug(klass: self.class, name: :process_write_event, message: '')
        execute_callback(event: event, identity: event.ident, callbacks: @write_callbacks, kind: 'WRITE')
      end

      def process_timer_event(event:)
        Logger.debug(klass: self.class, name: :process_timer_event, message: '')
        @timers.fire_expired
      end

      def register(fd:, request:, filter:, flags:, fflags: 0, data: 0, udata: 0)
        return if @change_count >= MAX_EVENTS # guard against too many events

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

      def make_timeout_struct(delay_ms)
        if delay_ms > 0
          Logger.debug(klass: self.class, name: :make_timeout_struct, message: "ms [#{delay_ms}]")
          seconds = delay_ms / 1_000
          nanoseconds = (delay_ms % 1_000) * 1_000_000
        else
          Logger.debug(klass: self.class, name: :make_timeout_struct, message: 'ms [0], poll immediately')
          seconds = 0
          nanoseconds = 0
        end

        @timespec[:tv_sec] = seconds
        @timespec[:tv_nsec] = nanoseconds
        @timespec
      end

      def no_timeout
        TimeSpecStruct.new
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

      def error?(event)
        (event.flags & Constants::EV_ERROR) > 0
      end
    end

    class ActivePoller < KqueuePoller
    end
  end
end
