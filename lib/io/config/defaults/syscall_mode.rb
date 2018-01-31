class IO
  module Config
    class Defaults
      DEFAULT_SYSCALL_MODE = :nonblocking
      @syscall_mode = DEFAULT_SYSCALL_MODE
      @syscall_backend = nil
      SYSCALL_MODES = [:blocking, :nonblocking].freeze

      class << self
        attr_reader :syscall_mode, :syscall_backend
      end

      def self.configure_syscall_mode(mode: DEFAULT_SYSCALL_MODE)
        return [-2, nil] unless SYSCALL_MODES.include?(mode)

        @syscall_backend = if mode == :blocking
                             Internal::Backend::Sync
                           else
                             Internal::Backend::Async
                           end

        @syscall_mode = mode

        [@syscall_mode, nil]
      end

      # Used for setting the default syscall mode for the
      # duration of the given block.
      def self.syscall_mode_switch(mode:)
        original_mode = syscall_mode
        configure_syscall_mode(mode: mode)
        yield
      ensure
        configure_syscall_mode(mode: original_mode)
      end

      configure_syscall_mode(mode: DEFAULT_SYSCALL_MODE)
    end
  end
end
