require 'forwardable'

class IO
  module Internal
    # Convenience class to be used by Thread and Fiber. Those classes
    # have an odd way of dealing with thread-local and fiber-local variables.
    # This is a storage mechanism to replace the standard mechanism.
    #
    class Local
      def initialize
        @storage = {}
        @thread_creator = Thread.current
        @fiber_creator = Fiber.current
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

      private

      def ownership_check
        return if @thread_creator == Thread.current && @fiber_creator == Fiber.current
        raise ThreadError, "Access to local storage disallowed from non-originating thread or fiber!"
      end
    end

    # Done as a module so we can easily add it to a running Thread or Fiber via #extend.
    # e.g. add this to root Thread via Thread.main.extend(LocalMixin)
    #
    module LocalMixin
      def local
        @local ||= Local.new
      end
    end
  end
end
