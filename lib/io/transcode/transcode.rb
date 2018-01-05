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
      else
        raise "unknown encoding [#{encoding.name}]"
      end
    end
    
    def initialize(io:, encoding:)
      @io = io
      @encoding = encoding # sanity check that this is correct type
    end
  end
  
  class UTF8 < Transcode
    def initialize(io:)
      super(io: io, encoding: Encoding::UTF_8)
    end

    def each(limit:, separator:, skip:, offset: 0, timeout: nil)
      
    end
  end
end
