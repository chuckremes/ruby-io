class IO
  class Transcode
    module EachReaders
      class PrivateReader < Mixins::Enumerable::EachReader

        def initialize(io:, limit:, separator:, offset:, timeout:)
          super(io: io, limit: limit, offset: offset, timeout: timeout)
          @separator = separator
          @separator_size = @separator ? @separator.bytesize : 0
        end

        def each(&block)
          if @limit && @separator.nil?
            read_to_limit(&block)
          elsif @limit.nil? && @separator
            read_to_separator(&block)
          elsif @limit && @separator
            read_to_separator_with_limit(&block)
          else
            read_all(&block)
          end
        end
      end

      class ASCII_8BIT < PrivateReader

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

                yield(total_read, errno, string, offset)

                string = String.new # reset!
              else
                # have not found separator yet, save and keep reading
                offset += rc
                string << buffer
              end
            elsif rc == 0
              # if we get here then we read to EOF and will return
              # the remainder of file; might also return empty string
              yield(string.bytesize, nil, string, offset + string.bytesize)
            else
              # error!
              yield(rc, errno, nil, offset)
            end
            
            # must return this as value of block so #read_to can update *offset*
            offset
          end
        end

        # Returns a string that either terminated by the +separator+ OR
        # the string is a maximum of +limit+ bytes. The former string may
        # be less than +limit+ bytes.
        def read_to_separator_with_limit(&block)
          string = String.new

          read_to(size: @limit) do |rc, errno, buffer, offset|
            if rc > 0
              if count = buffer.index(@separator)
                count += @separator_size # include separator in string
                string << buffer.slice!(0, count)
                total_read = string.bytesize
                offset += total_read

                yield(total_read, errno, string, offset)

                string = String.new # reset!
              else
                # did not find separator, yield +limit+-sized string
                offset += rc

                yield(rc, errno, buffer, offset)

                string = String.new # reset!
              end
            elsif rc == 0
              # if we get here then we read to EOF and will return
              # the remainder of file; might also return empty string
              yield(string.bytesize, nil, string, offset + string.bytesize)
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
