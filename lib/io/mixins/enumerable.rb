class IO
  module Mixins
    #
    #  io = File.open(path: 'path/to/file', flags: Config::DefaultFlags)
    #  io.each(limit: 5, offset: 0) do |rc, errno, string, new_offset|
    #    ...
    #  end
    #
    module Enumerable

      # The bare-bones EachReader. This treats everything as ASCII_8BIT and
      # only provides support for reading +limit+ bytes. Internally the
      # method may buffer some data which means it could read more than
      # +limit+ bytes. If this behavior is not desired, see
      # UnbufferedEnumerable. Since most enumerations are intended to go
      # through the entire stream, this version may read ahead and buffer
      # some data. The intent is to minimize the number of syscalls to
      # the underlying system and therefore get slightly better
      # performance. Need benchmarks to prove this.
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
        READ_SIZE = 4096

        def initialize(io:, limit:, offset:, timeout:)
          @io = io
          @limit = limit
          @offset = offset
          @timeout = timeout

          @saved_buffer = String.new # always returns encoding ASCII_8BIT
          @read_buffer  = ::FFI::MemoryPointer.new(READ_SIZE)
        end

        def each(&block)
          read_to_limit(&block)
        end

        def read_to_limit(&block)
          read_to(size: @limit) do |rc, errno, buffer, offset|
            if rc >= 0
              offset += rc
              yield(rc, errno, buffer, offset)
            else
              yield(rc, errno, nil, offset)
            end

            # must return this as value of block so #read_to can update *offset*
            offset
          end
        end

        def read_to(size:, &block)
          offset = @offset

          begin
            rc, errno, buffer = read_from_storage(
              io: @io,
              limit: size,
              offset: offset,
              timeout: @timeout
            )

            offset = yield(rc, errno, buffer, offset)
          end until rc.zero? # end of file
        end

        def read_from_storage(io:, limit:, offset:, timeout:)
          if limit > @saved_buffer.size
            # we cannot satisfy request from saved bytes
            # so try to read another full buffer from FD
            rc, errno, buffer, offset = io.read(
              nbytes: READ_SIZE,
              offset: offset + @saved_buffer.size, # move offset past remaining buffer
              buffer: @read_buffer,
              timeout: timeout
            )

            # failure
            return [rc, errno, nil] if rc < 0

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
        EachReader.new(io: self, limit: limit, offset: offset, timeout: timeout).each(&blk)
        self
      end

      def each_byte(offset:, timeout: nil)
        each(limit: 1, offset: offset, timeout: timeout) do |rc, errno, byte, offset|
          yield(rc, errno, byte, offset)
        end
      end
    end


    module UnbufferedEnumerable

      # The unbuffered EachReader. This treats everything as ASCII_8BIT and
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
      class UnbufferedEachReader < Enumerable::EachReader
        def initialize(io:, limit:, offset:, timeout:)
          super
          @saved_buffer = nil
          @read_buffer  = ::FFI::MemoryPointer.new(limit)
        end

        def read_from_storage(io:, limit:, offset:, timeout:)
          rc, errno, buffer, offset = io.read(
            nbytes: limit,
            offset: offset,
            buffer: @read_buffer,
            timeout: timeout
          )

          return [nil, rc, errno] if rc < 0

          [rc, nil, @read_buffer.get_bytes(0, rc)]
        end
      end

      def each(limit:, offset: 0, timeout: nil, &blk)
        # fail silently for now. need to hook up error policy here.
        #raise LimitArgError.new(limit) if limit < 1
        #raise OffsetArgError.new(offset) if offset < 0
        UnbufferedEachReader.new(io: self, limit: limit, offset: offset, timeout: timeout).each(&blk)
        self
      end

      def each_byte(offset:, timeout: nil)
        each(limit: 1, offset: offset, timeout: timeout) do |rc, errno, byte, offset|
          yield(rc, errno, byte, offset)
        end
      end
    end
  end
end
