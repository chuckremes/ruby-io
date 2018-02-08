require_relative 'select'

class IO
  module Platforms

    class SelectPoller < Poller
      def initialize(self_pipe:)
        @read_master_set   = FDSetStruct.new
        @read_working_set  = FDSetStruct.new
        @write_master_set  = FDSetStruct.new
        @write_working_set = FDSetStruct.new

        @timeval = TimeValStruct.new

        super
        Logger.debug(klass: self.class, name: 'select poller', message: 'allocated poller')
      end

      def max_allowed
        Constants::FDSET_SIZE
      end

      def register_read(fd:, request:)
        super

        @read_master_set.set(fd: fd)
        @change_count += 1

        Logger.debug(klass: self.class, name: 'select poller', message: "registered for read, fd [#{fd}]")
      end

      def register_write(fd:, request:)
        super

        @write_master_set.set(fd: fd)
        @change_count += 1

        Logger.debug(klass: self.class, name: 'select poller', message: "registered for write, fd [#{fd}]")
      end

      # Dispatches the registered reads and writes to +select+.
      def poll
        #Logger.debug(klass: self.class, name: 'select poller', message: 'calling select')
        Logger.debug(klass: self.class, name: :poll, message: "timeout [#{shortest_timeout.inspect}]")
        @change_count = 0
        # Copy FDs from master to working set if there are any; else set local working set
        # to nil so select(2) ignores it. Saves on reallocating working_set every loop.
        read_working_set = @read_master_set.max_fd >= 0 ? @read_master_set.copy_to(copy: @read_working_set) : nil
        write_working_set = @write_master_set.max_fd >= 0 ? @write_master_set.copy_to(copy: @write_working_set) : nil

        max_fd = @read_master_set.max_fd > @write_master_set.max_fd ?
          @read_master_set.max_fd :
          @write_master_set.max_fd

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
            execute_callback(identity: fd, callbacks: callbacks, kind: kind, event: nil)
            count -= 1
          end
        end
      end

      def make_timeout_struct(delay_ms)
        if delay_ms > 0
          Logger.debug(klass: self.class, name: :make_timeout_struct, message: "ms [#{delay_ms}]")
          seconds = delay_ms / 1_000
          microseconds = (delay_ms % 1_000) * 1_000
          Logger.debug(klass: self.class, name: :make_timeout_struct, message: "seconds [#{seconds}], micro [#{microseconds}]")
        else
          Logger.debug(klass: self.class, name: :make_timeout_struct, message: 'ms [0], poll immediately')
          seconds = 0
          microseconds = 0
        end        

        @timeval[:tv_sec] = seconds
        @timeval[:tv_usec] = microseconds
        @timeval
      end

      def no_timeout
        TimeValStruct.new
      end

      def delete_from_selector(fd:)
        Logger.debug(klass: self.class, name: :delete_from_selector, message: "deleting, fd [#{fd}]")
        @read_master_set.clear(fd: fd)
        @write_master_set.clear(fd: fd)
        Logger.debug(klass: self.class, name: :delete_from_selector, message: "deleted, fd [#{fd}]")
      end
    end

    class ActivePoller < SelectPoller
    end
  end
end
