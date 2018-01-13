class IO
  module Config
    class Defaults
      DEFAULT_READ_CACHE = 1024 * 32 # 32k
      @read_cache_size = DEFAULT_READ_CACHE
      
      def self.read_cache_size
        @read_cache_size
      end
      
      def self.configure_read_cache_size(size: DEFAULT_READ_CACHE)
        return [-2, nil] unless size > 128

        @read_cache_size = size

        [@read_cache_size, nil]
      end
    end
  end
end
