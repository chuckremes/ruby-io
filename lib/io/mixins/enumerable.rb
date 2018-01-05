class IO
  module Mixins
    module Enumerable

      # The bare-bones EachReader. This treats everything as ASCII_8BIT and
      # only provides support for reading +limit+ bytes.
      #
      # When the read is successful, method yields a string with encoding
      # ASCII_8BIT, the number of bytes read, and an errno (nil).
      #
      # When the read fails, method yields a nil, the error code, and
      # the errno.
      #
      # When the #each method exits, it returns the total number of bytes
      # read.
      #
      # Anything that requires interpretation of a byte (like a line
      # separator or skip char) must be handled by the enumerator supplied
      # by the appropriate Transposer.
      #
      class EachReader
        def initialize(io:, limit:, offset:, timeout:)
          @io = io
          @limit = limit
          @offset = offset
          @timeout = timeout
        end

        def each(&block)
          read_to_limit(&block)
        end

        def read_to_limit(&block)
          wanted = limit = @limit
          offset = @offset
          buffer = ::FFI::MemoryPointer.new(wanted)

          begin
            rc, errno, buffer = read_from_storage(
              io: @io,
              limit: @limit,
              offset: offset,
              timeout: @timeout
            )

            if rc < 0
              yield(nil, rc, errno)
            else
              yield(buffer, rc, nil)
              offset += rc
            end
          end until rc.zero? # end of file
        end

        def read_from_storage(io:, limit:, offset:, timeout:)
          # only allocate once, reuse
          @read_buffer ||= ::FFI::MemoryPointer.new(limit)

          rc, errno, buffer = io.read(
            nbytes: limit,
            offset: offset,
            buffer: @read_buffer,
            timeout: timeout
          )

          if rc < 0
            [nil, rc, errno]
          else
            [rc, nil, @read_buffer.get_bytes(0, rc)]
          end
        end
      end

      def each(limit:, offset: 0, timeout: nil, &blk)
        # fail silently for now. need to hook up error policy here.
        #raise LimitArgError.new(limit) if limit < 1
        #raise OffsetArgError.new(offset) if offset < 0
        EachReader.new(io: self, limit: limit, offset: offset, timeout: timeout).each(&blk)
        self
      end

      def each_byte(offset:, timeout: nil)
        each(limit: 1, offset: offset, timeout: timeout) do |byte, rc, errno|
          yield(byte, rc, errno)
        end
      end
    end


    module BufferedEnumerable

      # The vuffered EachReader. This treats everything as ASCII_8BIT and
      # only provides support for reading +limit+ bytes. However, since
      # most enumerations are intended to go through the entire stream,
      # this version may read ahead and buffer some data. The intent is
      # to minimize the number of syscalls to the underlying system and
      # therefore get slightly better performance. Need benchmarks.
      #
      # When the read is successful, method yields a string with encoding
      # ASCII_8BIT, the number of bytes read, and an errno (nil).
      #
      # When the read fails, method yields a nil, the error code, and
      # the errno.
      #
      # When the #each method exits, it returns the total number of bytes
      # read.
      #
      # Anything that requires interpretation of a byte (like a line
      # separator or skip char) must be handled by the enumerator supplied
      # by the appropriate Transposer.
      #
      class BufferedEachReader < Enumerable::EachReader
        READ_SIZE = 4096

        def initialize(io:, limit:, offset:, timeout:)
          super
          @saved_buffer = String.new # always returns encoding ASCII_8BIT
          @read_buffer  = ::FFI::MemoryPointer.new(READ_SIZE)
        end

        def read_from_storage(io:, limit:, offset:, timeout:)
          if limit > @saved_buffer.size
            # we cannot satisfy request from saved bytes
            # so try to read another full buffer from FD
            rc, errno, buffer = io.read(
              nbytes: READ_SIZE,
              offset: offset + @saved_buffer.size, # move offset past remaining buffer
              buffer: @read_buffer,
              timeout: timeout
            )

            if rc < 0
              # failure
              [nil, rc, errno]
            else
              # @saved_buffer may have data or may be 0 on first time through;
              # we need the MINIMUM of our limit minus saved buffer OR the
              # total bytes read just now
              bytes_needed = [limit - @saved_buffer.size, rc].min

              # prepare string to return to caller by combining any saved
              # bytes and reading +bytes_needed+ bytes from refilled buffer
              string_buffer = if bytes_needed > 0
                # minimize String copying by only doing this append when bytes available
                @saved_buffer << @read_buffer.get_bytes(0, bytes_needed)
              else
                @saved_buffer
              end

              # lastly, we may have bytes left in read buffer; save the unused
              # bytes for a future request; if at EOF, this is 0
              @saved_buffer = if (rc - bytes_needed) > 0
                @read_buffer.get_bytes(bytes_needed, rc - bytes_needed)
              else
                String.new
              end

              [string_buffer.size, nil, string_buffer]
            end
          elsif limit <= @saved_buffer.size

            # we can satisfy entire request from buffered bytes
            # read whichever is smaller, the remaining buffered bytes or +limit+ bytes
            length = [@saved_buffer.size, limit].min
            [length, nil, @saved_buffer.slice!(0, length)]
          end
        end
      end

      def each(limit:, offset: 0, timeout: nil, &blk)
        # fail silently for now. need to hook up error policy here.
        #raise LimitArgError.new(limit) if limit < 1
        #raise OffsetArgError.new(offset) if offset < 0
        BufferedEachReader.new(io: self, limit: limit, offset: offset, timeout: timeout).each(&blk)
        self
      end

      def each_byte(offset:, timeout: nil)
        each(limit: 1, offset: offset, timeout: timeout) do |byte, rc, errno|
          yield(byte, rc, errno)
        end
      end
    end
  end
end
