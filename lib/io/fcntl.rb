class IO
  class FCNTL
    module Constants
      include Platforms::Constants::FCNTL
    end

    class << self
      def fcntl(fd:, cmd:, args: nil, timeout: nil)
        Config::Defaults.syscall_backend.setup
        reply = Config::Defaults.syscall_backend.fcntl(fd: fd, cmd: cmd, args: args, timeout: timeout)
        [reply[:rc], reply[:errno]]
      end

      def get_fd_flag(fd:, timeout: nil)
        fcntl(fd: fd, cmd: Constants::F_GETFD, timeout: timeout)
      end

      def set_fd_flag(fd:, flag:, timeout: nil)
        rc, errno = get_status_flags(fd: fd, timeout: timeout)

        if rc < 0
          return [rc, errno]
        elsif (rc & flag) == 0
          return [0, nil]
        end

        current_flags = rc | flag
        fcntl(fd: fd, cmd: Constants::F_SETFD, args: current_flags.to_i, timeout: timeout)
      end

      def get_status_flags(fd:, timeout: nil)
        fcntl(fd: fd, cmd: Constants::F_GETFL, timeout: timeout)
      end

      def set_status_flag(fd:, flag:, timeout: nil)
        rc, errno = get_status_flags(fd: fd, timeout: timeout)

        if rc < 0
          return [rc, errno]
        elsif (rc & flag) == 0
          return [0, nil]
        end

        current_flags = rc | flag
        fcntl(fd: fd, cmd: Constants::F_SETFL, args: current_flags.to_i, timeout: timeout)
      end

      def clear_status_flag(fd:, flag:, timeout: nil)
        rc, errno = get_status_flags(fd: fd, timeout: timeout)

        if rc < 0
          return [rc, errno]
        elsif (reply[:rc] & flag) == 0
          return [0, nil]
        end

        current_flags = rc & ~flag
        fcntl(fd: fd, cmd: Constants::F_SETFL, args: current_flags.to_i, timeout: timeout)
      end

      def set_nonblocking(fd:, timeout: nil)
        set_status_flag(fd: fd, flag: Constants::O_NONBLOCK, timeout: timeout)
      end

      def set_close_on_exec(fd:, timeout: nil)
        set_fd_flag(fd: fd, flag: Constants::FD_CLOEXEC, timeout: timeout)
      end

      def duplicate_fd(fd:, fd_minimum:, timeout: nil)
        fcntl(fd: fd, cmd: Constants::F_DUPFD, args: fd_minimum, timeout: timeout)
      end
    end

    def initialize(fd:)
      @fd = fd
    end

    def get_flag(timeout: nil)
      FCNTL.get_flag(fd: @fd, timeout: timeout)
    end

    def set_nonblocking(timeout: nil)
      FCNTL.set_nonblocking(fd: @fd, timeout: timeout)
    end

    def set_close_on_exec(timeout: nil)
      FCNTL.set_close_on_exec(fd: @fd, timeout: timeout)
    end

    def duplicate_fd(timeout: nil)
      FCNTL.duplicate_fd(fd: @fd, timeout: timeout)
    end

    def get_fd_flag(timeout: nil)
      FCNTL.get_fd_flag(fd: @fd, timeout: timeout)
    end

    def set_fd_flag(flag:, timeout: nil)
      FCNTL.set_fd_flag(fd: @fd, flag: flag, timeout: timeout)
    end

    def get_status_flag(timeout: nil)
      FCNTL.get_status_flag(fd: @fd, timeout: timeout)
    end

    def set_status_flag(flag:, timeout:)
      FCNTL.set_status_flag(fd: @fd, flag: flag, timeout: timeout)
    end
  end
end
