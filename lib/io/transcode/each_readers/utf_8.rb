class IO
  class Transcode
    module EachReaders

      class UTF_8 < PrivateReader
        def initialize(**kwargs)
          super
          @encoding = Encoding::UTF_8
          @separator = @separator ? @separator.force_encoding(Encoding::ASCII_8BIT) : nil
          @debug = false
        end

        # We know the rules of how a UTF-8 char is laid out.
        # 1. If high bit is 0, then it's ASCII and we are on a char
        #    boundary.
        # 2. If 2 highest bits are set, then this is a 2-byte char.
        # 3. If 3 highest bits are set, then this is a 3-byte char.
        # 4. If 4 highest bits are set, then this is a 4-byte char.
        # 5. If high bit is 0, then we are in the middle of a char.
        #
        def count_chars(string)
          char_count = 0
          i = 0
          while i < string.bytesize
            ordinal = string[i].ord
            print "i [#{i}] char [#{string[i].inspect}, #{string[i+1].inspect}], ordinal [#{ordinal}] " if @debug
            
            if (ordinal & 0x80) == 0 # 1-byte char
              char_count += 1
              puts "1-byte-char, char_count [#{char_count}]" if @debug
            elsif (ordinal & 0xF0) == 0xF0 # 4-byte char
              char_count += 1
              i += 3
              puts "4-byte-char, char_count [#{char_count}]" if @debug
            elsif (ordinal & 0xE0) == 0xE0 # 3-byte char
              char_count += 1
              i += 2
              puts "3-byte-char, char_count [#{char_count}]" if @debug
            elsif (ordinal & 0xC0) == 0xC0 # 2-byte char
              char_count += 1
              i += 1
              puts "2-byte-char, char_count [#{char_count}]" if @debug
            else
              # likely in middle of char; scan forward up to 2 more
              # bytes
              # also, have a boundary condition here; we might have
              # a short read so if we run out of bytes to check just
              # ignore this half-formed char
              puts "middle-of-char" if @debug
              j = i + 1
              k = 0
              while k < 2 && j < string.bytesize
                break if (string[j].ord & 0xC0) != 0x80
                k += 1
                j += 1
                i += 1
              end
            end
            
            i += 1
          end
          char_count
        end

        # Returns the byte index corresponding to a string of
        # +length+ chars.
        #
        def char_index(length:, string:)
          i = 0
          char_count = 0
          while i < string.bytesize && char_count < length
            ordinal = string[i].ord
            
            if (ordinal & 0x80) == 0 # 1-byte char
              char_count += 1
            elsif (ordinal & 0xF0) == 0xF0 # 4-byte char
              char_count += 1
              i += 3
            elsif (ordinal & 0xE0) == 0xE0 # 3-byte char
              char_count += 1
              i += 2
            elsif (ordinal & 0xC0) == 0xC0 # 2-byte char
              char_count += 1
              i += 1
            else
              # likely in middle of char; scan forward up to 2 more
              # bytes
              # also, have a boundary condition here; we might have
              # a short read so if we run out of bytes to check just
              # ignore this half-formed char
              j = i + 1
              k = 0
              while k < 2 && j < string.bytesize
                break if (string[j].ord & 0xC0) != 0x80
                k += 1
                j += 1
                i += 1
              end
            end
            
            i += 1
          end
          i
        end

        def read_to_limit(&block)
          string = String.new
          carry_rc = 0

          read_to(size: @limit) do |rc, errno, buffer, offset|
            if rc > 0
              buffer.prepend(string)
              size = count_chars(buffer)
              
              if size == @limit
                offset += rc
                yield(carry_rc + rc, errno, buffer.force_encoding(@encoding), offset, carry_rc + rc)
                string = String.new
              elsif size > @limit
                byte_index = char_index(length: @limit, string: buffer)
                string = buffer.byteslice(0, byte_index)
                offset += rc
                yield(carry_rc + rc, errno, string.force_encoding(@encoding), offset, carry_rc + rc)
                
                string = buffer.byteslice(byte_index, buffer.bytesize)
                carry_rc = 0
              else
                # ideally we could save the left over bytes to @saved_buffer here. however, since
                # this was a "short read" where the bytes didn't give us enough characters, we know
                # that we already read the MAX bytes. If we save to @saved_buffer, then next call
                # to read_from_storage will try to satisfy the whole +limit+ read from the buffer.
                # That buffer is too short! We'll go into infinite loop. Therefore, we need to
                # save here and stitch the saved bits back onto the newly read buffer.
                # Need a better way.
                string << buffer
                offset += rc
                carry_rc += rc
              end
            elsif rc == 0
              yield(carry_rc, errno, string.force_encoding(@encoding), offset, carry_rc)
            else
              yield(rc, errno, nil, offset)
            end
            
            # must return this as value of block so #read_to can update *offset*
            offset
          end
        end

        def read_to_separator(&block)
          string = String.new

          read_to(size: READ_SIZE) do |rc, errno, buffer, offset|
            if rc > 0
              if count = buffer.index(@separator)
                count += @separator_size # include separator in string
                string << buffer.slice!(0, count)
                @saved_buffer << buffer # put back unused bytes

                total_read = string.bytesize
                offset += total_read

                yield(total_read, errno, string.force_encoding(@encoding), offset)

                string = String.new # reset!
              else
                # have not found separator yet, save and keep reading
                offset += rc
                string << buffer
              end
            elsif rc == 0
              # if we get here then we read to EOF and will return
              # the remainder of file; might also return empty string
              yield(string.bytesize, nil, string.force_encoding(@encoding), offset + string.bytesize)
            else
              # error!
              yield(rc, errno, nil, offset)
            end
            
            # must return this as value of block so #read_to can update *offset*
            offset
          end
        end

        def read_to_separator_with_limit(&block)
          string = String.new

          read_to(size: @limit) do |rc, errno, buffer, offset|
            if rc > 0
              if count = buffer.index(@separator)
                count += @separator_size # include separator in string
                string << buffer.slice!(0, count)
                total_read = string.bytesize
                offset += total_read

                yield(total_read, errno, string.force_encoding(@encoding), offset)

                string = String.new # reset!
              else
                # did not find separator, yield +limit+-sized string
                offset += rc

                yield(rc, errno, buffer.force_encoding(@encoding), offset)

                string = String.new # reset!
              end
            elsif rc == 0
              # if we get here then we read to EOF and will return
              # the remainder of file; might also return empty string
              yield(string.bytesize, nil, string.force_encoding(@encoding), offset + string.bytesize)
            else
              # error!
              yield(rc, errno, nil, offset)
            end
            
            # must return this as value of block so #read_to can update *offset*
            offset
          end
        end


      end
    end
  end
end
