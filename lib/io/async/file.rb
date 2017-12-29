require 'io/internal/states/file/closed'
require 'io/internal/states/file/readonly'
require 'io/internal/states/file/readwrite'
require 'io/internal/states/file/writeonly'

class IO
  module Async
    class File
      class << self
        def open(path:, flags: nil, timeout: nil, error_policy: nil)
          Private.setup
          mode = Config::Mode.from_flags(flags)
          result = Internal::Backend::Async.open(path: path, flags: flags.to_i, mode: mode.to_i, timeout: timeout)

          if result[:rc] > 0
            if flags.readwrite?
              File.new(fd: result[:rc], flags: flags, mode: mode, state: :readwrite, error_policy: error_policy)
            elsif flags.readonly?
              File.new(fd: result[:rc], flags: flags, mode: mode, state: :readonly, error_policy: error_policy)
            elsif flags.writeonly?
              File.new(fd: result[:rc], flags: flags, mode: mode, state: :writeonly, error_policy: error_policy)
            else
              raise "Unknown file mode!!!"
            end
          else
            nil
          end
        end
      end

      def initialize(fd:, flags:, mode:, state: :readonly, error_policy:)
        @creator = Thread.current
        Private.setup
        @policy = error_policy || Config::Defaults.error_policy

        @context = if :readonly == state
          Internal::States::File::ReadOnly.new(fd: fd, backend: Internal::Backend::Async)
        elsif :writeonly == state
          Internal::States::File::WriteOnly.new(fd: fd, backend: Internal::Backend::Async)
        elsif :readwrite == state
          Internal::States::File::ReadWrite.new(fd: fd, backend: Internal::Backend::Async)
        else
          Internal::States::File::Closed.new(fd: -1, backend: Internal::Backend::Async)
        end
      end

      def to_i
        safe_delegation do |context|
          context.to_i
        end
      end

      def close(timeout: nil)
        rc, errno = safe_delegation do |context|
          rc, errno, behavior = context.close
          [rc, errno]
        end
        [rc, errno]
      end

      def read(nbytes:, offset:, buffer: nil, timeout: nil)
        rc, errno, buffer = safe_delegation do |context|
          rc, errno = context.read(nbytes: nbytes, offset: offset, buffer: buffer, timeout: timeout)
          [rc, errno, buffer]
        end
        [rc, errno, buffer]
      end

      def write(offset:, string:, timeout: nil)
        rc, errno = safe_delegation do |context|
          rc, errno = context.write(offset: offset, string: string, timeout: timeout)
          [rc, errno]
        end
        [rc, errno]
      end


      private

      def safe_delegation
        # Always call Private.setup. User may have created object in a thread and
        # already run Private.setup. However, transferring the object to another
        # thread means that it might not have the same async setup performed yet, so
        # any instance method must check first and perform setup.
        Private.setup
        if Config::Defaults.multithread_policy.check(io: self, creator: @creator)
          yield @context
        end
      end

      def update_context(behavior)
        @context = behavior
      end
    end
  end
end
