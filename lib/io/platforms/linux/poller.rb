require 'set'

class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion. It maintains it's change_count internally
    # so parallel calls would likely corrupt the changelist.
    class EPollPoller
      MAX_EVENTS = 10
      SHORT_TIMEOUT = 1_000 # milliseconds

      def initialize
        @epoll_fd = Platforms.epoll_create1(0)

        # fatal error if we can't allocate the kqueue
        raise "Fatal error, epoll failed to allocate, rc [#{@epoll_fd}], errno [#{::FFI.errno}]" if @epoll_fd < 0

        @events_memory = ::FFI::MemoryPointer.new(Platforms::EPollEventStruct, MAX_EVENTS)
        @events = MAX_EVENTS.times.to_a.map do |index|
          Platforms::EPollEventStruct.new(@events_memory + index * Platforms::EPollEventStruct.size)
        end
        @change_count = 0
        @read_callbacks = {}
        @write_callbacks = {}
        @timer_callbacks = {}
        @readers = Set.new
        @writers = Set.new
        @timers = Common::Timers.new
        Logger.debug(klass: self.class, name: 'epoll poller', message: 'epoll allocated!')
      end

      def max_allowed
        MAX_EVENTS
      end

      def register_timer(duration:, request:)
        @timers.add_oneshot(delay: duration, callback: request)
      end

      def register_read(fd:, request:)
        @read_callbacks[fd] = request

        register(
          fd: fd,
          filter: Constants::EPOLLIN | Constants::EPOLLONESHOT,
          operation: add_or_modify(fd: fd)
        )
        @readers << fd # on future calls, we will know to just modify existing registered FD
        Logger.debug(klass: self.class, name: 'epoll poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        @write_callbacks[fd] = request

        register(
          fd: fd,
          filter: Constants::EPOLLOUT | Constants::EPOLLONESHOT,
          operation: add_or_modify(fd: fd)
        )
        @writers << fd
        Logger.debug(klass: self.class, name: 'epoll poller', message: "registered for write, fd [#{fd}]")
      end

      # Waits for epoll events. We can receive up to MAX_EVENTS in reponse.
      def poll
        Logger.debug(klass: self.class, name: 'epoll_wait poller', message: 'calling epoll_wait')
        rc = Platforms.epoll_wait(@epoll_fd, @events[0], MAX_EVENTS, shortest_timeout)
        @change_count = 0
        Logger.debug(klass: self.class, name: 'epoll poller', message: "epoll_wait returned [#{rc}] events!")

        if rc >= 0
          rc.times { |index| process_event(event: @events[index]) }
          @timers.fire_expired
        else
          Logger.debug(klass: self.class, name: 'epoll_wait poller', message: "rc [#{rc}], errno [#{::FFI.errno}]")
        end
      end

      private

      def process_event(event:)
        if event.read?
          process_read_event(event: event)
        elsif event.write?
          process_write_event(event: event)
        #elsif event.filter == Constants::EVFILT_TIMER
        #  process_timer_event(event: event)
        else
          raise "Fatal: unknown event #{event.inspect}"
        end
      end

      def process_read_event(event:)
        execute_callback(event: event, identity: event.fd, callbacks: @read_callbacks, kind: 'READ')
      end

      def process_write_event(event:)
        execute_callback(event: event, identity: event.fd, callbacks: @write_callbacks, kind: 'WRITE')
      end

      def process_timer_event(event:)
        execute_callback(event: event, identity: event.udata, callbacks: @timer_callbacks, kind: 'TIMER')
      end

      def execute_callback(event:, identity:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: 'kqueue poller', message: "execute [#{kind}] callback for fd [#{identity}]")

        block = callbacks.delete(identity)
        if block
          block.call
        else
          raise "Got [#{kind}] event for fd [#{identity}] with no registered callback"
        end
      end

      # If an FD has already been registered, registering it a second time with CTL_ADD
      # returns errno 17 / EEXIST. Must modify existing FDs instead.
      #
      # FIXME: When an FD is closed, need a way to detect that and remove from Poller.
      # Otherwise, we'll have FDs registered that should not be and will likely return
      # errors at bad moments.
      def add_or_modify(fd:)
        if @readers.member?(fd) || @writers.member?(fd)
          Constants::EPOLL_CTL_MOD
        else
          Constants::EPOLL_CTL_ADD
        end
      end

      def register(fd:, filter:, operation:)
        event = @events[@change_count]
        event.setup(fd: fd, events: filter)
        rc = Platforms.epoll_ctl(@epoll_fd, operation, fd, event)
        raise "Fatal error, epoll_ctl returned [#{rc}], errno [#{::FFI.errno}]" if rc < 0
        @change_count += 1
      end

      def shortest_timeout
        delay_ms = @timers.wait_interval.to_i
        delay_ms = 50 if delay_ms.zero?
        delay_ms
      end
    end

    class Poller < EPollPoller
    end
  end
end
