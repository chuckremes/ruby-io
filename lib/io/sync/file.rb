require 'io/internal/states/file/closed'
require 'io/internal/states/file/readonly'
require 'io/internal/states/file/readwrite'
require 'io/internal/states/file/writeonly'

class IO
  module Sync
    class File
      include Mixins::Enumerable

      class << self
        def open(path:, flags: nil, error_policy: nil)
          mode = Config::Mode.from_flags(flags)
          result = Internal::Backend::Sync.open(path: path, flags: flags.to_i, mode: mode.to_i, timeout: nil)

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
        @policy = error_policy || Config::Defaults.error_policy

        @context = if :readonly == state
          Internal::States::File::ReadOnly.new(fd: fd, backend: Internal::Backend::Sync)
        elsif :writeonly == state
          Internal::States::File::WriteOnly.new(fd: fd, backend: Internal::Backend::Sync)
        elsif :readwrite == state
          Internal::States::File::ReadWrite.new(fd: fd, backend: Internal::Backend::Sync)
        else
          Internal::States::File::Closed.new(fd: -1, backend: Internal::Backend::Sync)
        end
      end

      def to_i
        safe_delegation do |context|
          context.to_i
        end
      end

      def close(timeout: nil)
        rc, errno = safe_delegation do |context|
          rc, errno, behavior = context.close(timeout: timeout)
          [rc, errno]
        end
        [rc, errno]
      end

      def read(nbytes:, offset:, buffer: nil, timeout: nil)
        rc, errno, string = safe_delegation do |context|
          rc, errno = context.read(nbytes: nbytes, offset: offset, buffer: buffer, timeout: timeout)
          [rc, errno, string]
        end
        [rc, errno, string]
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
