class IO
  module Internal
    module States
      class File
        class ReadWrite
          def initialize(fd:, backend:, read_cache:)
            @fd = fd
            @backend = backend
            @read_cache = read_cache
          end

          def to_i
            @fd
          end

          def close(timeout: nil)
            results = @backend.close(fd: @fd, timeout: timeout)
            rc = results[:rc]
            if rc.zero? || Errno::EBADF == rc
              [0, nil, Closed.new(fd: -1, backend: @backend)]
            else
              if Errno::EINTR == rc
                [-1, nil, self]
              elsif Errno::EIO == rc
                [-1, nil, self]
              else
                # We have encountered a bug; fail hard regardless of Policy
                STDERR.puts "Fatal error: close(2) returned code [#{rc}] and errno [#{errno}] which is an exceptional unhandled case"
                exit!(123)
              end
            end
          end

          # Buffered read, falls through to __pread__ to refresh or pass through cache.
          def read(nbytes:, offset:, buffer: nil, timeout: nil)
            @read_cache.pread(
              nbytes: nbytes,
              offset: offset,
              buffer: buffer,
              timeout: timeout
            )
          end

          # Unbuffered read
          #
          def __pread__(nbytes:, offset:, buffer: nil, timeout: nil)
            read_buffer = buffer || ::FFI::MemoryPointer.new(nbytes)
            reply = @backend.pread(fd: @fd, buffer: read_buffer, nbytes: nbytes, offset: offset, timeout: timeout)

            string = if reply[:rc] >= 0
              # only return a string if user didn't pass in their own buffer
              buffer ? nil : buffer.read_string
            else
              nil
            end

            [reply[:rc], reply[:errno], string]
          end

          def write(offset:, string:, timeout: nil)
            nbytes = string.bytesize
            buffer = ::FFI::MemoryPointer.new(nbytes)
            buffer.write_string(string)
            reply = @backend.pwrite(fd: @fd, buffer: buffer, nbytes: nbytes, offset: offset, timeout: timeout)
            @read_cache.write_invalidation(offset: offset) if reply[:rc] > 0
            [reply[:rc], reply[:errno]]
          end
        end
      end
    end
  end
end
