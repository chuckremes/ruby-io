class IO
  # Should provide methods identical to those in the Sync/Async classes
  # for reading/writing/sending/receiving data. When creating a Transcode
  # wrapper, the user specifies the destination encoding.
  #
  # Since all IO
  # is performed using ASCII_8BIT, this class is responsible for formatting
  # all outgoing strings properly before they are written as bytes.
  #
  # Likewise, any data read from an IO should be converted to the appropriate
  # encoding for consumption by other Ruby objects.
  #
  # Delegates to underlying IO object for any operations that do not require
  # transcoding.
  #
  # Internally, IO represents all data as ASCII_8BIT. When this data flows
  # over the "border" to an outside object or flows in from an outside
  # object, some transcoding may need to take place.
  #
  class Transcode
    LF = "\n"
    CR = "\r"
    NEWLINE = ::FFI::Platform::IS_WINDOWS ? CR+LF : LF

    SEPARATOR = NEWLINE

    # Envisioning that some transcoding may require some nonstandard
    # support. Using the factory method to create the Transcode class let's
    # it pick the appropriate supporting class and instantiate it directly.
    #
    # May not be needed... mostly a thought experiment for now.
    #
    # Raises ArgumentError if +encoding+ cannot be found.
    #
    def self.choose_for(encoding:, io:)
      encoding = Encoding.find(encoding) if encoding.is_a?(String)
      case encoding
      when Encoding::UTF_8
        UTF8.new(io: io)
      when nil
        ASCII_8BIT.new(io: io)
      else
        raise "unknown encoding [#{encoding.name}]"
      end
    end

    def initialize(io:, encoding:)
      @io = io
      @encoding = encoding # sanity check that this is correct type
    end
  end

  class ASCII_8BIT < Transcode
    def initialize(io:)
      super(io: io, encoding: Encoding::ASCII_8BIT)
    end

    # +limit+ nil means program should return up to +separator+ or the
    # whole file is +separator+ is also nil.
    #
    # +separator+ defaults to newline (\n on most systems, \r\n on Windows).
    #
    def each(limit: nil, separator: NEWLINE, offset: 0, timeout: nil, &block)
      EachReaders::ASCII_8BIT.new(
        io: @io,
        limit: limit,
        separator: separator,
        offset: offset,
        timeout: timeout
      ).each(&block)

      self
    end
  end

  class UTF8 < Transcode
    def initialize(io:)
      super(io: io, encoding: Encoding::UTF_8)
    end

    def each(limit: nil, separator: NEWLINE, offset: 0, timeout: nil, &block)
      EachReaders::UTF_8.new(
        io: @io,
        limit: limit,
        separator: separator,
        offset: offset,
        timeout: timeout
      ).each(&block)

      self
    end
  end
end
