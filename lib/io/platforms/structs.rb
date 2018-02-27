class IO
  module POSIX

    class AddrInfoStruct < ::FFI::Struct
      include Platforms::Structs::AddrInfoStructLayout
      attr_accessor :sock_addr_ref

      def self.copy_from(struct)
        copy = AddrInfoStruct.new
        copy.pointer.__copy_from__(struct.pointer, copy.size)

        copy[:ai_canonname] = if struct[:ai_canonname].nil? || struct[:ai_canonname].null?
          ::FFI::Pointer::NULL
        else
          ::FFI::MemoryPointer.from_string(struct[:ai_canonname].read_string_to_null)
        end

        # We need to save a reference to our new copy of the SockAddr*Struct so it
        # doesn't get garbage collected. We need that Ruby obj reference to keep it
        # alive
        copy.sock_addr_ref = if struct[:ai_family] == POSIX::PF_INET
          SockAddrInStruct.copy_from(SockAddrInStruct.new(struct[:ai_addr]))
        else
          SockAddrIn6Struct.copy_from(SockAddrIn6Struct.new(struct[:ai_addr]))
        end
        copy[:ai_addr] = copy.sock_addr_ref.respond_to?(:pointer) ? copy.sock_addr_ref.pointer : nil
        copy
      end

      def inspect
        addr = if POSIX::PF_INET == self[:ai_family]
          SockAddrInStruct.new(self[:ai_addr])
        else
          SockAddrIn6Struct.new(self[:ai_addr])
        end

        string = ""
        string += "family     [#{self[:ai_family]}],\n"
        string += "socktype   [#{self[:ai_socktype]}],\n"
        string += "protocol   [#{self[:ai_protocol]}]\n"
        string += "addrlen    [#{self[:ai_addrlen]}],\n"
        string += "addr       [#{addr.to_ip}],\n"
        string += "canonnname [#{self[:ai_canonname]}],\n"
        string += "next       [#{self[:ai_next]}]\n"
      end
    end

    class SockAddrInStruct < ::FFI::Struct
      include Platforms::Structs::SockAddrInStructLayout

      def self.copy_from(struct)
        copy = SockAddrInStruct.new
        copy.pointer.__copy_from__(struct.pointer, copy.size)
        copy
      end

      def port_to_s
        Platforms.htons(self[:sin_port])
      end

      def to_ip
        str = ::FFI::MemoryPointer.new(:string, POSIX::INET_ADDRSTRLEN)
        # tricky; make a helper method to return a pointer to a struct's field
        # so we can abstract out this work
        sin_addr_ptr = Platforms::Structs.address_of(struct: self, field: :sin_addr)
        hsh = POSIX.inet_ntop(self[:sin_family], sin_addr_ptr, str, str.size)
        hsh[:rc]
      end

      def inspect
        "
          sin_family [#{self[:sin_family]}],
          sin_port [#{port_to_s}],
          sin_addr [#{self[:sin_addr]}],
          ip [#{to_ip}]
        "
      end
    end

    class SockAddrIn6Struct < ::FFI::Struct
      include Platforms::Structs::SockAddrIn6StructLayout

      def self.copy_from(struct)
        copy = SockAddrIn6Struct.new
        copy.pointer.__copy_from__(struct.pointer, copy.size)
        copy
      end

      def port_to_s
        Platforms::Functions.htons(self[:sin6_port])
      end

      def inspect
        "
          sin6_family [#{self[:sin6_family]}],
          sin6_port [#{port_to_s}],
          sin6_addr [#{self[:sin6_addr]}],
          ip [#{to_ip}]
        "
      end

      def to_ip
        str = ::FFI::MemoryPointer.new(:string, POSIX::INET6_ADDRSTRLEN)
        # tricky; make a helper method to return a pointer to a struct's field
        # so we can abstract out this work
        sin_addr_ptr = Platforms::Structs.address_of(struct: self, field: :sin6_addr)
        hsh = POSIX.inet_ntop(self[:sin6_family], sin_addr_ptr, str, str.size)
        hsh[:rc]
      end
    end

    class SockAddrStorageStruct < ::FFI::Struct
      include Platforms::Structs::SockAddrStorageStructLayout
    end

    class SockAddrUnStruct < ::FFI::Struct
      include Platforms::Structs::SockAddrUnStructLayout

      def self.copy_from(struct)
        copy = SockAddrUnStruct.new
        copy.pointer.__copy_from__(struct.pointer, copy.size)
        copy
      end
    end

    class SockLenStruct < ::FFI::Struct
      layout :socklen, :socklen_t
    end

  end
end
