require 'ffi'

module Platforms
  extend ::FFI::Library

  ffi_lib ::FFI::Library::LIBC

  # attach to functions common to all POSIX-compliant platforms
  attach_function :inet_ntop, [:int, :pointer, :pointer, :socklen_t], :int, :blocking => true
end

class AddrInt < ::FFI::Struct
  layout :addr, :uint32
end


class InAddrStruct < ::FFI::Struct
  layout :s_addr, :uint32

  def inspect
    #self[:s_addr]
  end

  def to_s
    inspect
  end
end

class SockAddrInStruct < ::FFI::Struct
  layout :sin_len, :uint8,
    :sin_family, :uint16,
    :sin_port, :uint16,
    :sin_addr, :uint32,
    :sin_zero, [:uint8, 8]
end


#addr_int = AddrInt.new
#addr_int[:addr] = 0

addr = SockAddrInStruct.new
addr[:sin_len] = 0
addr[:sin_family] = 0
addr[:sin_port] = 0
addr[:sin_addr] = 0

uint32 = ::FFI::MemoryPointer.new(:uint32)
sin_addr_ptr = ::FFI::Pointer.new(:uint8, addr.pointer.address + addr.offset_of(:sin_addr))


string = ::FFI::MemoryPointer.new(:uint8, 50)

#rc = Platforms.inet_ntop(2, addr.pointer.address + 5, string, 50)
rc = Platforms.inet_ntop(2, sin_addr_ptr, string, 50)


#p rc, addr_int[:addr], string.read_string
p rc, addr[:sin_addr], string.read_string
