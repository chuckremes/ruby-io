require_relative 'internal/states/file/closed'
require_relative 'internal/states/file/readonly'
require_relative 'internal/states/file/readwrite'
require_relative 'internal/states/file/writeonly'

class IO
  class File
    include Mixins::Enumerable

    class << self
      def open(path:, flags: nil, timeout: nil, error_policy: nil)
        Config::Defaults.syscall_backend.setup
        mode = Config::Mode.from_flags(flags)
        result = Config::Defaults.syscall_backend.open(path: path, flags: flags.to_i, mode: mode.to_i, timeout: timeout)

        raise "could not allocate file instance" if result[:rc] < 0

        file = if flags.readwrite?
          File.new(fd: result[:rc], flags: flags, mode: mode, state: :readwrite, error_policy: error_policy)
        elsif flags.readonly?
          File.new(fd: result[:rc], flags: flags, mode: mode, state: :readonly, error_policy: error_policy)
        elsif flags.writeonly?
          File.new(fd: result[:rc], flags: flags, mode: mode, state: :writeonly, error_policy: error_policy)
        else
          raise "Unknown file mode!!!"
        end

        block_given? ? yield(file) : file
      end
    end

    def initialize(fd:, flags:, mode:, state: :readonly, error_policy:)
      @creator = Thread.current
      Config::Defaults.syscall_backend.setup
      @policy = error_policy || Config::Defaults.error_policy
      read_cache = Internal::PReadCache.new(io: self, size: Config::Defaults.read_cache_size)

      @context = if state == :readonly
                   Internal::States::File::ReadOnly.new(
                     fd: fd,
                     backend: Config::Defaults.syscall_backend,
                     read_cache: read_cache
                   )
                 elsif state == :writeonly
                   Internal::States::File::WriteOnly.new(
                     fd: fd,
                     backend: Config::Defaults.syscall_backend
                   )
                 elsif state == :readwrite
                   Internal::States::File::ReadWrite.new(
                     fd: fd,
                     backend: Config::Defaults.syscall_backend,
                     read_cache: read_cache
                   )
                 else
                   Internal::States::File::Closed.new(
                     fd: -1,
                     backend: Config::Defaults.syscall_backend
                   )
                 end
    end

    def to_i
      safe_delegation(&:to_i)
    end

    def close(timeout: nil)
      safe_delegation do |context|
        rc, errno, behavior = context.close
        [rc, errno]
      end
    end

    # Reads +nbytes+ starting at +offset+ from the file and puts
    # the result into +buffer+. Buffer must be a FFI::MemoryPointer
    # large enough to accommodate +nbytes+.
    #
    # When no +buffer+ is given by the user, the system will allocate
    # its own. Given a successful read operation, this method will return
    # an array in the order:
    #  [return_code, error_number, string, new_offset]
    #
    # When user has provided their own buffer, a successful read operation
    # will return an array in the order:
    #  [return_code, error_number, nil, new_offset]
    #
    # In this case, the user is expected to extract the string from the
    # +buffer+ manually.
    #
    def read(nbytes:, offset:, buffer: nil, timeout: nil)
      safe_delegation do |context|
        rc, errno, string = context.read(nbytes: nbytes, offset: offset, buffer: buffer, timeout: timeout)

        offset = rc >= 0 ? offset + rc : offset
        block_given? ? yield([rc, errno, string, offset]) : [rc, errno, string, offset]
      end
    end

    def __pread__(nbytes:, offset:, buffer: nil, timeout: nil)
      safe_delegation do |context|
        rc, errno, string = context.__pread__(nbytes: nbytes, offset: offset, buffer: buffer, timeout: timeout)

        offset = rc >= 0 ? offset + rc : offset
        block_given? ? yield([rc, errno, string, offset]) : [rc, errno, string, offset]
      end
    end

    # Writes +string.bytesize+ bytes starting at +offset+ into file.
    #
    # A successful write returns an array in the order:
    #  [return_code, error_number, new_offset]
    #
    def write(offset:, string:, timeout: nil)
      safe_delegation do |context|
        rc, errno = context.write(offset: offset, string: string, timeout: timeout)
        offset = rc >= 0 ? offset + rc : offset
        block_given? ? yield([rc, errno, offset]) : [rc, errno, offset]
      end
    end


    private

    def safe_delegation
      # Always call Config::Defaults.syscall_backend.setup. User may have created
      # object in a thread and already run Config::Defaults.syscall_backend.setup.
      # However, transferring the object to another
      # thread means that it might not have the same async setup performed yet, so
      # any instance method must check first and perform setup.
      Config::Defaults.syscall_backend.setup
      yield(@context) if Config::Defaults.multithread_policy.check(io: self, creator: @creator)
    end

    def update_context(behavior)
      @context = behavior
    end
  end
end
