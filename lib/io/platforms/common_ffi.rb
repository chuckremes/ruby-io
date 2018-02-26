require 'ffi'

class IO
  module Platforms
    module Functions
      extend ::FFI::Library
      ffi_lib ::FFI::Library::LIBC
    end

    module Constants
      extend ::FFI::Library
    end

    # Load platform-specific files
    if ::FFI::Platform::IS_BSD
      require_relative 'bsd/ffi'
    elsif ::FFI::Platform::IS_LINUX
      require_relative 'linux/ffi'
    else
      # Can setup select(2) here as a backup for kqueue(2) and epoll(2)
      require_relative 'common/select_poller'
    end

    # Load support for items common to all POSIX platforms
    require_relative 'common/ffi'
    #require_relative 'common/select_poller'
  end
end
