class IO
  module Platforms
    module Structs

      #
      # Time
      #

      class TimeValStruct < ::FFI::Struct
        layout \
          :tv_sec, :time_t,
          :tv_usec, :int32

        def inspect
          "tv_sec [#{self[:tv_sec].inspect}], tv_usec [#{self[:tv_usec].inspect}]"
        end
      end

      #
      # Network
      #


      #
      # Network
      #
      def self.address_of(struct:, field:)
        ::FFI::Pointer.new(:uint8, struct.pointer.address + struct.offset_of(field))
      end

#      class IfAddrsStruct < ::FFI::Struct
#        layout :ifa_next, :pointer,
#          :ifa_name, :string,
#          :ifa_flags, :int,
#          :ifa_addr, :pointer,
#          :ifa_netmask, :pointer,
#          :ifa_broadaddr, :pointer,
#          :ifa_dstaddr, :pointer
#      end
#
#      class SockAddrStruct < ::FFI::Struct
#        layout :sa_len, :uint8,
#          :sa_family, :sa_family_t,
#          :sa_data, [:uint8, 14]
#
#        def inspect
#          [self[:sa_len], self[:sa_family], self[:sa_data].to_s]
#        end
#      end
#
#      class SockAddrStorageStruct < ::FFI::Struct
#        layout :ss_len, :uint8,
#          :ss_family, :sa_family_t,
#          :ss_data, [:uint8, 126]
#      end
#
#      class SockLenStruct < ::FFI::Struct
#        layout :socklen, :socklen_t
#      end
#
#      class TimevalStruct < ::FFI::Struct
#        layout :tv_sec, :time_t,
#          :tv_usec, :suseconds_t
#      end
#
#      class SockAddrInStruct < ::FFI::Struct
#        layout :sin_len, :uint8,
#          :sin_family, :sa_family_t,
#          :sin_port, :ushort,
#          :sin_addr, :uint32,
#          :sin_zero, [:uint8, 8]
#
#        def port_to_s
#          Platforms.htons(self[:sin_port])
#        end
#
#        def to_ip
#          str = ::FFI::MemoryPointer.new(:string, Platforms::INET_ADDRSTRLEN)
#          # tricky; make a helper method to return a pointer to a struct's field
#          # so we can abstract out this work
#          sin_addr_ptr = Platforms.address_of(struct: self, field: :sin_addr)
#          hsh = Platforms::Functions.inet_ntop(self[:sin_family], sin_addr_ptr, str, str.size)
#          hsh[:rc]
#        end
#
#        def inspect
#          "sin_len [#{self[:sin_len]}],
#          sin_family [#{self[:sin_family]}],
#          sin_port [#{port_to_s}],
#          sin_addr [#{self[:sin_addr]}],
#          ip [#{to_ip}]"
#        end
#
#        def self.copy_to_new(struct)
#          copy = SockAddrInStruct.new
#          copy[:sin_len] = struct[:sin_len]
#          copy[:sin_family] = struct[:sin_family]
#          copy[:sin_port] = struct[:sin_port]
#          copy[:sin_addr] = struct[:sin_addr]
#          copy
#        end
#      end
#
#      class SockAddrIn6Struct < ::FFI::Struct
#        layout :sin6_len, :uint8,
#          :sin6_family, :sa_family_t,
#          :sin6_port, :ushort,
#          :sin6_flowinfo, :int,
#          :sin6_addr, [:uint8, 16],
#          :sin6_scope_id, :int
#
#        def port_to_s
#          Platforms.htons(self[:sin6_port])
#        end
#
#        def inspect
#          "sin6_len [#{self[:sin6_len]}],
#          sin6_family [#{self[:sin6_family]}],
#          sin6_port [#{port_to_s}],
#          sin6_addr [#{self[:sin6_addr]}],
#          ip [#{to_ip}]"
#        end
#
#        def to_ip
#          str = ::FFI::MemoryPointer.new(:string, Platforms::INET6_ADDRSTRLEN)
#          # tricky; make a helper method to return a pointer to a struct's field
#          # so we can abstract out this work
#          sin_addr_ptr = Platforms.address_of(struct: self, field: :sin6_addr)
#          hsh = Platforms::Functions.inet_ntop(self[:sin6_family], sin_addr_ptr, str, str.size)
#          hsh[:rc]
#        end
#
#        def self.copy_to_new(struct)
#          copy = SockAddrIn6Struct.new
#          copy[:sin6_len] = struct[:sin6_len]
#          copy[:sin6_family] = struct[:sin6_family]
#          copy[:sin6_port] = struct[:sin6_port]
#          copy[:sin6_flowinfo] = struct[:sin6_flowinfo]
#          copy[:sin6_addr] = struct[:sin6_addr]
#          copy[:sin6_scope_id] = struct[:sin6_scope_id]
#          copy
#        end
#      end
#
#      class SockAddrUnStruct < ::FFI::Struct
#        layout :sun_len, :uint8,
#          :sun_family, :sa_family_t,
#          :sun_path, [:uint8, 104]
#
#        def self.copy_to_new(struct)
#          copy = self.class.new
#          copy[:sun_len] = struct[:sun_len]
#          copy[:sun_family] = struct[:sun_family]
#          copy[:sun_path] = struct[:sun_path]
#          copy
#        end
#      end

    end
  end
end
