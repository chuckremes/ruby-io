class IO
  module Sync
    class FCNTL
      module Constants
        include Platforms::Constants::FCNTL
      end

      class << self
        def fcntl(fd:, cmd:, args: nil)
          Internal::Backend::Sync.fcntl(fd: fd, cmd: cmd, args: args)
        end

        def get_fd_flag(fd:)
          fcntl(fd: fd, cmd: Constants::F_GETFD)
        end

        def set_fd_flag(fd:, flag:)
          current_flags = get_status_flags(fd: fd)
          
          if reply[:rc] < 0
            return [reply[:rc], reply[:errno]]
          elsif (reply[:rc] & flag) == 0
            return [0, nil]
          end

          current_flags = reply[:rc] | flag
          fcntl(fd: fd, cmd: Constants::F_SETFD, args: current_flags.to_i)
        end

        def get_status_flags(fd:)
          fcntl(fd: fd, cmd: Constants::F_GETFL)
        end

        def set_status_flag(fd:, flag:)
          current_flags = get_status_flags(fd: fd)
          
          if reply[:rc] < 0
            return [reply[:rc], reply[:errno]]
          elsif (reply[:rc] & flag) == 0
            return [0, nil]
          end

          current_flags = reply[:rc] | flag
          fcntl(fd: fd, cmd: Constants::F_SETFL, args: current_flags.to_i)
        end

        def clear_status_flag(fd:, flag:)
          current_flags = get_status_flags(fd: fd)
          
          if reply[:rc] < 0
            return [reply[:rc], reply[:errno]]
          elsif (reply[:rc] & flag) == 0
            return [0, nil]
          end

          current_flags = reply[:rc] & ~flag
          fcntl(fd: fd, cmd: Constants::F_SETFL, args: current_flags.to_i)
        end

        def set_nonblocking(fd:)
          set_status_flag(fd: fd, flag: Constants::O_NONBLOCK)
        end

        def set_close_on_exec(fd:)
          set_fd_flag(fd: fd, flag: Constants::FD_CLOEXEC)
        end

        def duplicate_fd(fd:, fd_minimum:)
          fcntl(fd: fd, cmd: Constants::F_DUPFD, args: fd_minimum)
        end
      end

      def initialize(fd:)
        @fd = fd
      end

      def get_flag
        FCNTL.get_flag(fd: @fd)
      end

      def set_nonblocking
        FCNTL.set_nonblocking(fd: @fd)
      end

      def set_close_on_exec
        FCNTL.set_close_on_exec(fd: @fd)
      end

      def duplicate_fd
        FCNTL.duplicate_fd(fd: @fd)
      end

      def get_fd_flag
        FCNTL.get_fd_flag(fd: @fd)
      end

      def set_fd_flag(flag:)
        FCNTL.set_fd_flag(fd: @fd, flag: flag)
      end

      def get_status_flag
        FCNTL.get_status_flag(fd: @fd)
      end

      def set_status_flag(flag:)
        FCNTL.set_status_flag(fd: @fd, flag: flag)
      end
    end
  end
end
