class IO
  module Platforms

    # Register for read and write events. Upon firing, the given +request+ will be
    # called to process the +fd+.
    #
    # Not re-entrant or thread-safe. This class assumes it is called from a single
    # thread in a serialized fashion. It maintains it's change_count internally
    # so parallel calls would likely corrupt the changelist.
    class SelectPoller
      MAX_EVENTS = 10
      NO_TIMEOUT = TimeSpecStruct.new
      SHORT_TIMEOUT = TimeSpecStruct.new.tap { |ts| ts[:tv_sec] = 1 }

      def initialize
        @master_read_set = FDSetStruct.new
        @master_write_set = FDSetStruct.new

        @read_callbacks = {}
        @write_callbacks = {}
        @timer_callbacks = {}
        Logger.debug(klass: self.class, name: 'select poller', message: 'poller allocated!')
      end

      def max_allowed
        Constants::FDSET_SIZE
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
        register(
          fd: fd,
          request: request,
          fdset: @master_read_set
        )
        Logger.debug(klass: self.class, name: 'select poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        @write_callbacks[fd] = request
        register(
          fd: fd,
          request: request,
          fdset: @master_write_set
        )
        Logger.debug(klass: self.class, name: 'select poller', message: "registered for write, fd [#{fd}]")
      end

      # Dispatches the registered reads and writes to +select+.
      def poll
        Logger.debug(klass: self.class, name: 'select poller', message: 'calling select')
        read_working_set = @master_read_set.max_fd > 0 ? @master_read_set.copy : nil
        write_working_set = @master_write_set.max_fd > 0 ? @master_write_set.copy : nil
        max_fd = [@master_read_set.max_fd, @master_write_set.max_fd].max
        
        rc = Platforms.select(max_fd + 1, read_working_set, write_working_set, nil, SHORT_TIMEOUT)
        Logger.debug(klass: self.class, name: 'select poller', message: "select returned [#{rc}] events!")

        if rc >= 0
          p read_working_set
          read_working_set && (read_working_set.max_fd + 1).times do |index|
            break if 0 == rc
            puts "checking read fd [#{index}]"
            if read_working_set.set?(fd: index)
              @master_read_set.clear(fd: index)
              process_read_event(event: index)
              rc -= 1
            end
          end
          
          p write_working_set
          write_working_set && (write_working_set.max_fd + 1).times do |index|
            break if 0 == rc
            puts "checking write fd [#{index}]"
            if write_working_set.set?(fd: index)
              @master_write_set.clear(fd: index)
              process_write_event(event: index)
              rc -= 1
            end
          end
        else
          Logger.debug(klass: self.class, name: 'select poller', message: "rc [#{rc}], errno [#{::FFI.errno}]")
        end
      end

      private

      def process_read_event(event:)
        execute_callback(identity: event, callbacks: @read_callbacks, kind: 'READ')
      end

      def process_write_event(event:)
        execute_callback(identity: event, callbacks: @write_callbacks, kind: 'WRITE')
      end

      def execute_callback(identity:, callbacks:, kind:)
        Logger.debug(klass: self.class, name: 'select poller', message: "execute [#{kind}] callback for fd [#{identity}]")
        block = callbacks.delete(identity)
        if block
          block.call
        else
          raise "Got [#{kind}] event for fd [#{identity}] with no registered callback"
        end
      end

      def register(fd:, request:, fdset:)
        fdset.set(fd: fd)
      end
    end

    class Poller < SelectPoller
    end
  end
end
