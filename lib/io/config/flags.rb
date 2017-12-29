
class IO
  module Config
    class Flags
      def initialize(value = 0)
        @value = value
      end

      def to_i
        @value
      end

      def readonly(state = true)
        toggle(state, Platforms::Constants::O_RDONLY)
      end

      def writeonly(state = true)
        toggle(state, Platforms::Constants::O_WRONLY)
      end

      def readwrite(state = true)
        toggle(state, Platforms::Constants::O_RDWR)
      end

      def nonblock(state = true)
        toggle(state, Platforms::Constants::O_NONBLOCK)
      end

      def append(state = true)
        toggle(state, Platforms::Constants::O_APPEND)
      end

      def create(state = true)
        toggle(state, Platforms::Constants::O_CREAT)
      end

      def truncate(state = true)
        toggle(state, Platforms::Constants::O_TRUNC)
      end

      def exclusive(state = true)
        toggle(state, Platforms::Constants::O_EXCL)
      end

      def close_on_exec(state = true)
        toggle(state, Platforms::Constants::FD_CLOEXEC)
      end

      def create?
        on?(Platforms::Constants::O_CREAT)
      end
      
      def readonly?
        on?(Platforms::Constants::O_RDONLY)
      end
      
      def writeonly?
        on?(Platforms::Constants::O_WRONLY)
      end
      
      def readwrite?
        on?(Platforms::Constants::O_RDWR)
      end

      private

      def toggle(on, constant)
        on ? enable(constant) : disable(constant)
      end

      def enable(constant)
        Flags.new(to_i | constant)
      end

      def disable(constant)
        Flags.new(to_i & (~constant))
      end

      def on?(constant)
        @value & constant
      end
    end

    DefaultFlags = Flags.new.readonly.close_on_exec
  end
end
