require 'ffi'

class IO
  module Platforms
    extend ::FFI::Library
    ffi_lib ::FFI::Library::LIBC

    # Load more common support
    require_relative 'common/ffi'
    require_relative 'common/timers'

    # Load platform-specific files
    if ::FFI::Platform::IS_BSD
      require_relative 'bsd/ffi'
      require_relative 'bsd/poller'
    elsif ::FFI::Platform::IS_LINUX
      require_relative 'linux/ffi'
      require_relative 'linux/poller'
    else
      # Can setup select(2) or poll(2) here as a backup for kqueue(2) and epoll(2)
      #require_relative 'common/poller'
    end
#    require_relative 'common/poller'
  end
end
