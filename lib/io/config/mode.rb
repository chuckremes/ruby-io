
class IO
  module Config
    class Mode

      # Certain flags imply a particular mode. Detect that here.
      def self.from_flags(flags)
        flags ||= (flags || DefaultFlags)

        # if flags include CREAT, then we need to set a mode
        flags.create? ? DefaultMode : nil
      end

      def initialize(value = 0)
        @value = value
      end

      def to_i
        @value
      end

      def owner_read(state = true)
        toggle(state, Platforms::Constants::S_IRUSR)
      end

      def owner_write(state = true)
        toggle(state, Platforms::Constants::S_IWUSR)
      end

      def owner_execute(state = true)
        toggle(state, Platforms::Constants::S_IXUSR)
      end

      def owner_rwx(state = true)
        owner_read(state).owner_write(state).owner_execute(state)
      end

      def group_read(state = true)
        toggle(state, Platforms::Constants::S_IRGRP)
      end

      def group_write(state = true)
        toggle(state, Platforms::Constants::S_IWGRP)
      end

      def group_execute(state = true)
        toggle(state, Platforms::Constants::S_IXGRP)
      end

      def group_rwx(state = true)
        group_read(state).group_write(state).group_execute(state)
      end

      def other_read(state = true)
        toggle(state, Platforms::Constants::S_IROTH)
      end

      def other_write(state = true)
        toggle(state, Platforms::Constants::S_IWOTH)
      end

      def other_execute(state = true)
        toggle(state, Platforms::Constants::S_IXOTH)
      end

      def other_rwx(state = true)
        other_read(state).other_write(state).other_execute(state)
      end
      
      private

      def toggle(on, constant)
        on ? enable(constant) : disable(constant)
      end

      def enable(constant)
        Mode.new(to_i | constant)
      end

      def disable(constant)
        Mode.new(to_i & (~constant))
      end
    end

    # Corresponds to mode 0664
    DefaultMode = Mode.new.owner_read.owner_write.group_read.group_write.other_read
  end
end
