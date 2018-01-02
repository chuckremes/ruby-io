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
        Logger.debug(klass: self.class, name: 'epoll poller', message: 'epoll allocated!')
      end

      def max_allowed
        MAX_EVENTS
      end

      def register_timer(duration:, request:)
#        @timer_callbacks[request.object_id] = request
#        register(
#          fd: 1,
#          request: request,
#          filter: Constants::EVFILT_TIMER,
#          flags: Constants::EV_ADD | Constants::EV_ENABLE | Constants::EV_ONESHOT,
#          fflags: Constants::NOTE_MSECONDS,
#          data: duration,
#          udata: request.object_id
#        )
#        Logger.debug(klass: self.class, name: 'kqueue poller', message: "registered for timer, object_id [#{request.object_id}]")
      end

      def register_read(fd:, request:)
        @read_callbacks[fd] = request
        add_or_modify = @readers.member?(fd) ? Constants::EPOLL_CTL_MODIFY : Constants::EPOLL_CTL_ADD

        register(
          fd: fd,
          filter: Constants::EPOLLIN | Constants::EPOLLONESHOT,
          operation: add_or_modify
        )
        @readers << fd # on future calls, we will know to just modify existing registered FD
        Logger.debug(klass: self.class, name: 'epoll poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        @write_callbacks[fd] = request
        add_or_modify = @readers.member?(fd) ? Constants::EPOLL_CTL_MODIFY : Constants::EPOLL_CTL_ADD

        register(
          fd: fd,
          filter: Constants::EPOLLOUT | Constants::EPOLLONESHOT,
          operation: add_or_modify
        )
        @writers << fd
        Logger.debug(klass: self.class, name: 'epoll poller', message: "registered for write, fd [#{fd}]")
      end

      # Waits for epoll events. We can receive up to MAX_EVENTS in reponse.
      def poll
        Logger.debug(klass: self.class, name: 'epoll_wait poller', message: 'calling epoll_wait')
        rc = Platforms.epoll_wait(@epoll_fd, @events[0], MAX_EVENTS, SHORT_TIMEOUT)
        @change_count = 0
        Logger.debug(klass: self.class, name: 'epoll poller', message: "epoll_wait returned [#{rc}] events!")

        if rc >= 0
          rc.times { |index| process_event(event: @events[index]) }
        else
          Logger.debug(klass: self.class, name: 'epoll_wait poller', message: "rc [#{rc}], errno [#{::FFI.errno}]")
        end
      end

      private

      def process_event(event:)
        p event
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
        p event
        block = callbacks.delete(identity)
        if block
          block.call
        else
          raise "Got [#{kind}] event for fd [#{identity}] with no registered callback"
        end
      end

      def register(fd:, filter:, operation:)
        event = @events[@change_count]
        event.setup(
          fd: fd,
          events: filter
        )
        rc = Platforms.epoll_ctl(@epoll_fd, operation, fd, event)
        raise "Fatal error, epoll_ctl returned [#{rc}], errno [#{::FFI.errno}]" if rc < 0
        @change_count += 1
      end
    end

    class Poller < EPollPoller
    end
  end
end
