class IO
  module Internal
    module States
      class File
        class Closed
          def initialize(fd:, backend:)
            @fd = fd
            @backend = backend
          end

          def to_i
            @fd
          end

          def close(timeout: nil)
            [-1, Errno::EBADF]
          end

          def read(nbytes:, offset:, buffer: nil, timeout: nil)
            __pread__(nbytes: nbytes, offset: offset, buffer: buffer, timeout: timeout)
          end

          def __pread__(nbytes:, offset:, buffer: nil, timeout: nil)
            [-1, Errno::EBADF]
          end

          def write(offset:, string:, timeout: nil)
            [-1, Errno::EBADF]
          end
        end
      end
    end
  end
end
