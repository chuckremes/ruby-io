require 'ffi'

class IO
  module Platforms
    extend ::FFI::Library

    ffi_lib ::FFI::Library::LIBC

    # attach to functions common to all POSIX-compliant platforms
    attach_function :open, [:pointer, :int, :int], :int, :blocking => true
    attach_function :close, [:int], :int, :blocking => true
    attach_function :pread, [:int, :pointer, :size_t, :off_t], :ssize_t, :blocking => true
    attach_function :pwrite, [:int, :pointer, :size_t, :off_t], :ssize_t, :blocking => true
    attach_function :write,       [:int, :pointer, :size_t], :ssize_t
    attach_function :socket, [:int, :int, :int], :int, :blocking => true
    attach_function :getaddrinfo, [:string, :string, :pointer, :pointer], :int, :blocking => true
    attach_function :freeaddrinfo, [:pointer], :int, :blocking => true
    attach_function :inet_ntop, [:int, :pointer, :pointer, :socklen_t], :string, :blocking => true
    attach_function :htons, [:uint16], :uint16, :blockinger => true
    attach_function :bind, [:int, :pointer, :socklen_t], :int, :blocking => true
    attach_function :connect, [:int, :pointer, :socklen_t], :int, :blocking => true
    attach_function :listen, [:int, :int], :int, :blocking => true
    attach_function :accept, [:int, :pointer, :pointer], :int, :blocking => true
    attach_function :ssend, :send, [:int, :pointer, :size_t, :int], :ssize_t, :blocking => true
    attach_function :sendmsg, [:int, :pointer, :int], :ssize_t, :blocking => true
    attach_function :sendto, [:int, :pointer, :size_t, :int, :pointer, :socklen_t], :ssize_t, :blocking => true
    attach_function :recv, [:int, :pointer, :size_t, :int], :ssize_t, :blocking => true
    
    # utilities
    attach_function :fcntl, [:int, :int, :int], :int, :blocking => true
    attach_function :getpagesize, [], :int

    # Load platform-specific files
    if ::FFI::Platform::IS_BSD
      require_relative 'bsd/ffi'
      require_relative 'bsd/poller'
    elsif ::FFI::Platform::IS_LINUX
      require_relative 'linux/ffi'
      require_relative 'linux/poller'
    else
      # Can setup select(2) or poll(2) here as a backup for kqueue(2) and epoll(2)
    end
  end
end
