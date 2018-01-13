class IO
  module Internal
    class PReadCache
      SUCCESSFUL_READ = [1, nil, nil]

      def initialize(size:, io:)
        @io = io
        @read_ahead_size = size
        @cache = ::FFI::MemoryPointer.new(size)

        invalidate!
      end

      def invalidate!
        @cache_offset_begin = @cache_offset_end = @cache_length = 0
      end

      # Forces cache invalidation if a write at +offset+ will be
      # inside the cache boundaries. Intended to be used by a #write method
      # to hint the cache to refresh if it's inserting bytes in the middle
      # or end of a file. If appending, this should invalidate.
      #
      def write_invalidation(offset:)
        invalidate! if offset.between?(@cache_offset_begin, @cache_offset_end)
      end

      def pread(nbytes:, offset:, buffer:, timeout:)
        return pread_pass_through(
          nbytes: nbytes,
          buffer: buffer,
          timeout: timeout
        ) if exceeds_cache?(nbytes)

        # +nbytes+ might fit within cache; next check to see if offset + nbytes
        # overlaps end of cache. if so, refresh buffer and return result from
        # newly buffered results.
        if blown_cache?(nbytes: nbytes, offset: offset)
          rc, errno, ignore = refresh_cache(offset: offset, timeout: timeout)
          return [rc, errno, ignore] if rc < 0
        end

        # if we got here, we can satisfy request from current cache
        from_cache(offset: offset, nbytes: nbytes, buffer: buffer)
      end

      # Read +nbytes+ exceeds the cache capacity, therefore we invalidate the
      # cache and pass through the request directly to the unbuffered read.
      def pread_pass_through(nbytes:, offset:, buffer:, timeout:)
        invalidate!
        @io.__pread__(nbytes: nbytes, offset: offset, buffer: buffer, timeout: timeout)
      end

      # Replace entire cache with a new read
      def refresh_cache(offset:, timeout:)
        #        if @cache_length > 0 && @cache_length < @read_ahead_size
        #          # special case... try to read whole file into cache
        #          # back up offset by difference between current length and read ahead
        #          difference = @read_ahead_size - @cache_length
        #          offset = offset - difference.abs
        #          offset = offset < 0 ? 0 : offset
        #        end

        #puts "refresh_cache, trying to read from offset [#{offset}], read ahead [#{@read_ahead_size}]"
        rc, errno, ignore = @io.__pread__(
          nbytes: @read_ahead_size,
          offset: offset,
          buffer: @cache,
          timeout: timeout
        )

        #puts "#{self.class}#refresh_cache, rc [#{rc}], errno [#{errno}]"
        return [rc, errno, ignore] if rc < 0

        # successful read!
        @cache_offset_begin = offset
        @cache_offset_end   = offset + rc
        @cache_length = rc
        #puts "#{self.class}#refresh_cache, begin [#{@cache_offset_begin}], end [#{@cache_offset_end}], length [#{@cache_length}]"
        SUCCESSFUL_READ
      end

      def from_cache(nbytes:, offset:, buffer:)
        #puts "from_cache!"
        # cannot return more than @cache_length - relative_offset bytes, so sanity check!
        adjusted_offset = relative_offset(offset)
        length = nbytes > (@cache_length - adjusted_offset) ?
          (@cache_length - adjusted_offset) :
          nbytes
        length = length < 0 ? 0 : length # negative check!
        string = @cache.get_bytes(adjusted_offset, length)

        #puts "from_cache, offset [#{offset}], rel_offset [#{relative_offset(offset)}], length [#{length}], string.size [#{string.size}], [\n#{string.inspect}\n]"
        if buffer
          # copy to user-supplied buffer
          buffer.put_bytes(
            0,
            string,
            0,
            string.bytesize
          )
          [length, nil, nil, offset + length]
        else
          [length, nil, string, offset + length]
        end
      end

      def relative_offset(offset)
        offset - @cache_offset_begin
      end

      def exceeds_cache?(nbytes)
        nbytes > @read_ahead_size
      end

      # True when we are requesting bytes where:
      # 1. Offset is outside the cache boundaries
      # 2. Offset + nbytes overlaps the cache end
      #
      def blown_cache?(nbytes:, offset:)
        between = !offset.between?(@cache_offset_begin, @cache_offset_end)
        overlap_end =  (relative_offset(offset) + nbytes) > @cache_offset_end
        #puts "blown_cache?, between [#{between}], overlap [#{overlap_end}]"

        between || overlap_end
      end
    end
  end
end
