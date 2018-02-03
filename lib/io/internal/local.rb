class IO
  module Internal
    # Convenience class to be used by Thread and Fiber. Those classes
    # have an odd way of dealing with thread-local and fiber-local variables.
    # This is a storage mechanism to replace the standard mechanism.
    #
    class Local
      def initialize(klass)
        @storage = {}
        @klass = klass
        @creator = if Fiber == klass || Thread == klass
          klass.current
        else
          raise "Cannot allocate local storage for class type [#{klass}]"
        end
      end

      def [](key)
        ownership_check
        @storage[key]
      end

      def []=(key, value)
        ownership_check
        @storage[key] = value
      end

      def key?(key)
        ownership_check
        @storage.key?(key)
      end

      def keys
        ownership_check
        @storage.keys
      end

      def safe?
        ownership_check
      rescue ThreadError
        false
      end

      private

      def ownership_check
        return if @creator == @klass.current
        raise ThreadError, "Access to local storage disallowed from non-originating thread or fiber!" +
        " Expected [#{@creator.object_id} / #{@creator.hash}] but got #{@klass}.current [#{@klass.current.object_id} / #{@klass.current.hash}]."
      end
    end

    # Separate class so we can initialize some variables we need for
    # support the Async functionality.
    class FiberLocal < Local
      def initialize
        super(Fiber)
        @storage[:sequence_no] = -1
        @storage[:_thr_hash] = Thread.current.hash
        @storage[:_fiber_hash] = Fiber.current.hash
      end
    end

    class ThreadLocal < Local
      def initialize
        super(Thread)
        @storage[:_thr_hash] = Thread.current.hash
        @storage[:_fiber_hash] = Fiber.current.hash
      end
    end

    # Done as a module so we can easily add it to a running Thread or Fiber via #extend.
    # e.g. add this to root Thread via Thread.main.extend(LocalMixin)
    #
    module ThreadLocalMixin
      def local
        @local ||= ThreadLocal.new
      end
    end

    module FiberLocalMixin
      def local
        @local ||= FiberLocal.new
      end
    end
  end
end
