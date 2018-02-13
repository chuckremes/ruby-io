require 'set'

class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion. It maintains it's change_count internally
    # so parallel calls would likely corrupt the changelist.
    class EPollPoller < Poller
      MAX_EVENTS = 25

      def initialize(self_pipe:)
        @epoll_fd = Platforms.epoll_create1(0)

        # fatal error if we can't allocate the selector
        raise "Fatal error, epoll failed to allocate, rc [#{@epoll_fd}], errno [#{::FFI.errno}]" if @epoll_fd < 0

        @events_memory = ::FFI::MemoryPointer.new(Platforms::EPollEventStruct, MAX_EVENTS)
        @events = MAX_EVENTS.times.to_a.map do |index|
          Platforms::EPollEventStruct.new(@events_memory + index * Platforms::EPollEventStruct.size)
        end
        @readers = Set.new
        @writers = Set.new

        super
        Logger.debug(klass: self.class, name: 'epoll', message: 'epoll allocated!')
      end

      def max_allowed
        MAX_EVENTS
      end

      def register_read(fd:, request:)
        super

        register(
          fd: fd,
          filter: Constants::EPOLLIN | Constants::EPOLLONESHOT,
          operation: add_or_modify(fd: fd)
        )
        @readers << fd # on future calls, we will know to just modify existing registered FD
        Logger.debug(klass: self.class, name: 'epoll', message: "registered for read, fd [#{fd}], readers #{@readers.inspect}")
      end

      def register_write(fd:, request:)
        super

        register(
          fd: fd,
          filter: Constants::EPOLLOUT | Constants::EPOLLONESHOT,
          operation: add_or_modify(fd: fd)
        )
        @writers << fd
        Logger.debug(klass: self.class, name: 'epoll', message: "registered for write, fd [#{fd}]")
      end

      # Waits for epoll events. We can receive up to MAX_EVENTS in reponse.
      def poll
        Logger.debug(klass: self.class, name: 'epoll_wait poller', message: 'calling epoll_wait')
        rc = Platforms.epoll_wait(@epoll_fd, @events[0], MAX_EVENTS, shortest_timeout)
        @change_count = 0
        Logger.debug(klass: self.class, name: 'epoll', message: "epoll_wait returned [#{rc}] events!")

        if rc >= 0
          rc.times { |index| process_event(event: @events[index]) }
          @timers.fire_expired
        else
          Logger.debug(klass: self.class, name: 'epoll', message: "rc [#{rc}], errno [#{::FFI.errno}]")
        end
      end

      private

      def process_event(event:)
        if event.error?
          process_error(event: event)
        elsif event.read?
          process_read_event(event: event)
        elsif event.write?
          process_write_event(event: event)
        else
          raise "Fatal: unknown event [#{event.inspect}], readers #{@readers.inspect}, writers #{@writers.inspect}"
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

      # If an FD has already been registered, registering it a second time with CTL_ADD
      # returns errno 17 / EEXIST. Must modify existing FDs instead.
      #
      def add_or_modify(fd:)
        if @readers.member?(fd) || @writers.member?(fd)
          Constants::EPOLL_CTL_MOD
        else
          Constants::EPOLL_CTL_ADD
        end
      end

      def register(fd:, filter:, operation:)
        event = nil
        unless operation == Constants::EPOLL_CTL_DEL
          event = @events[@change_count]
          event.setup(fd: fd, events: filter)
        end
        Logger.debug(klass: self.class, name: :register, message: "register fd [#{fd}], filter [#{filter}], op [#{operation}]")

        rc = Platforms.epoll_ctl(@epoll_fd, operation, fd, event)
        raise "Fatal error, epoll_ctl returned [#{rc}], errno [#{::FFI.errno}]" if rc < 0
        @change_count += 1
      end

      def make_timeout_struct(delay_ms)
        delay_ms
      end

      def no_timeout
        0
      end

      def delete_from_selector(fd:)
        Logger.debug(klass: self.class, name: :delete_from_selector, message: "deleting, fd [#{fd}]", force: true)
        r_exists = @readers.delete?(fd)
        w_exists = @writers.delete?(fd)
        exists = r_exists || w_exists
        return unless exists

        register(
          fd: fd,
          filter: 0,
          operation: Constants::EPOLL_CTL_DEL
        )
        Logger.debug(klass: self.class, name: :delete_from_selector, message: "deleted, fd [#{fd}]", force: true)
      end

      def error?(event)
        event.error?
      end
    end

    class ActivePoller < EPollPoller
    end
  end
end
