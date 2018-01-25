class IO
  module Platforms
    #
    # Typedefs
    #
    typedef :long,   :uintptr_t
    typedef :long,   :intptr_t

    #
    # BSD-specific functions
    #
    begin
      attach_function :kqueue, [], :int, :blocking => true
      attach_function :kevent, [:int, :pointer, :int, :pointer, :int, :pointer], :int, :blocking => true
    rescue ::FFI::NotFoundError
      # fallback to using select(2)
      require_relative '../common/poller'
    end

    #    struct kevent {
    #            uintptr_t       ident;          /* identifier for this event */
    #            int16_t         filter;         /* filter for event */
    #            uint16_t        flags;          /* general flags */
    #            uint32_t        fflags;         /* filter-specific flags */
    #            intptr_t        data;           /* filter-specific data */
    #            void            *udata;         /* opaque user data identifier */
    #    };
    class KEventStruct < ::FFI::Struct
      layout \
        :ident, :uintptr_t,
        :filter, :int16,
        :flags, :uint16,
        :fflags, :uint32,
        :data, :uintptr_t,
        :udata, :uint64

      def self.ev_set(kev_struct:, ident:, filter:, flags:, fflags:, data:, udata:)
        kev_struct[:ident] = ident
        kev_struct[:filter] = filter
        kev_struct[:flags] = flags
        kev_struct[:fflags] = fflags
        kev_struct[:data] = data
        kev_struct[:udata] = udata
      end

      def ev_set(ident:, filter:, flags:, fflags:, data:, udata:)
        KEventStruct.ev_set(
          kev_struct: self,
          ident: ident,
          filter: filter,
          flags: flags,
          fflags: fflags,
          data: data,
          udata: udata
        )
      end

      def ident(); self[:ident]; end
      def filter(); self[:filter]; end
      def flags(); self[:flags]; end
      def fflags(); self[:fflags]; end
      def data(); self[:data]; end
      def udata(); self[:udata]; end

      def inspect
        string = "[\n"
        string += "  ident:  #{ident}\n"
        string += "  filter: #{filter}\n"
        string += "  flags:  #{flags}\n"
        string += "  fflags: #{fflags}\n"
        string += "  data:   #{data}\n"
        string += "]\n"
        string
      end
    end

    # EV_SET(&kev, ident, filter, flags, fflags, data, udata);

    module Constants
      EVFILT_READ     = (-1)
      EVFILT_WRITE    = (-2)
      EVFILT_TIMER    = (-7)    # timers
      EVFILT_EXCEPT   = (-15)   # Exception events

      EVFILT_SYSCOUNT = 15

      # kevent system call flags
      KEVENT_FLAG_NONE         =      0x000    # no flag value
      KEVENT_FLAG_IMMEDIATE    =      0x001    # immediate timeout
      KEVENT_FLAG_ERROR_EVENTS =      0x002    # output events only include change errors


      # actions
      EV_ADD     = 0x0001  # add event to kq (implies enable)
      EV_DELETE  = 0x0002  # delete event from kq
      EV_ENABLE  = 0x0004  # enable event
      EV_DISABLE = 0x0008  # disable event (not reported)

      # flags
      EV_ONESHOT = 0x0010  # only report one occurrence
      EV_CLEAR   = 0x0020  # clear event state after reporting
      EV_RECEIPT = 0x0040  # force immediate event output

      EV_DISPATCH       = 0x0080  # disable event after reporting
      EV_UDATA_SPECIFIC = 0x0100  # unique kevent per udata value

      # returned values
      EV_EOF   = 0x8000  # EOF detected
      EV_ERROR = 0x4000  # error, data contains errno

      EV_FLAG0 = 0x1000  # filter-specific flag
      EV_FLAG1 = 0x2000  # filter-specific flag

      # EVFILT_READ specific flags
      EV_POLL   = EV_FLAG0
      EV_OOBAND = EV_FLAG1

      # EVFILT_TIMER specific flags
      NOTE_SECONDS  = 0x00000001  # data is seconds
      NOTE_USECONDS = 0x00000002  # data is microseconds
      NOTE_MSECONDS = 0x00000000  # data is milliseconds (default!)
      NOTE_NSECONDS = 0x00000004  # data is nanoseconds
    end

    class TimeSpecStruct < ::FFI::Struct
      layout \
        :tv_sec, :long,
        :tv_nsec, :long
    end

    # FIXME: Most of the socket structs below are DUPLICATED!
    
    def self.address_of(struct:, field:)
      ::FFI::Pointer.new(:uint8, struct.pointer.address + struct.offset_of(field))
    end

    class AddrInfoStruct < ::FFI::Struct
      attr_accessor :sock_addr_ref

      layout :ai_flags, :int,
        :ai_family, :int,
        :ai_socktype, :int,
        :ai_protocol, :int,
        :ai_addrlen, :int,
        :ai_canonname, :pointer,
        :ai_addr, :pointer,
        :ai_next, :pointer

      def self.copy_to_new(struct)
        copy = AddrInfoStruct.new
        copy[:ai_flags] = struct[:ai_flags]
        copy[:ai_family] = struct[:ai_family]
        copy[:ai_socktype] = struct[:ai_socktype]
        copy[:ai_protocol] = struct[:ai_protocol]
        copy[:ai_addrlen] = struct[:ai_addrlen]

        copy[:ai_canonname] = if struct[:ai_canonname].nil? || struct[:ai_canonname].null?
          ::FFI::Pointer::NULL
        else
          ::FFI::MemoryPointer.from_string(struct[:ai_canonname].read_string_to_null)
        end

        # We need to save a reference to our new copy of the SockAddr*Struct so it
        # doesn't get garbage collected. We need that Ruby obj reference to keep it
        # alive
        copy.sock_addr_ref = if struct[:ai_family] == Platforms::PF_INET
          SockAddrInStruct.copy_to_new(SockAddrInStruct.new(struct[:ai_addr]))
        else
          SockAddrIn6Struct.copy_to_new(SockAddrIn6Struct.new(struct[:ai_addr]))
        end
        copy[:ai_addr] = copy.sock_addr_ref.pointer
        copy
      end

      def inspect
        addr = if Platforms::PF_INET == self[:ai_family]
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

    class IfAddrsStruct < ::FFI::Struct
      layout :ifa_next, :pointer,
        :ifa_name, :string,
        :ifa_flags, :int,
        :ifa_addr, :pointer,
        :ifa_netmask, :pointer,
        :ifa_broadaddr, :pointer,
        :ifa_dstaddr, :pointer
    end

    class SockAddrStruct < ::FFI::Struct
      layout :sa_len, :uint8,
        :sa_family, :sa_family_t,
        :sa_data, [:uint8, 14]

      def inspect
        [self[:sa_len], self[:sa_family], self[:sa_data].to_s]
      end
    end

    class SockAddrStorageStruct < ::FFI::Struct
      layout :ss_len, :uint8,
        :ss_family, :sa_family_t,
        :ss_data, [:uint8, 126]
    end

    class SockLenStruct < ::FFI::Struct
      layout :socklen, :socklen_t
    end

    class TimevalStruct < ::FFI::Struct
      layout :tv_sec, :time_t,
        :tv_usec, :suseconds_t
    end

    class SockAddrInStruct < ::FFI::Struct
      layout :sin_len, :uint8,
        :sin_family, :sa_family_t,
        :sin_port, :ushort,
        :sin_addr, :uint32,
        :sin_zero, [:uint8, 8]

      def port_to_s
        Platforms.htons(self[:sin_port])
      end

      def to_ip
        str = ::FFI::MemoryPointer.new(:string, Platforms::INET_ADDRSTRLEN)
        # tricky; make a helper method to return a pointer to a struct's field
        # so we can abstract out this work
        sin_addr_ptr = Platforms.address_of(struct: self, field: :sin_addr)
        hsh = Platforms::Functions.inet_ntop(self[:sin_family], sin_addr_ptr, str, str.size)
        hsh[:rc]
      end

      def inspect
        "sin_len [#{self[:sin_len]}],
          sin_family [#{self[:sin_family]}],
          sin_port [#{port_to_s}],
          sin_addr [#{self[:sin_addr]}],
          ip [#{to_ip}]"
      end

      def self.copy_to_new(struct)
        copy = SockAddrInStruct.new
        copy[:sin_len] = struct[:sin_len]
        copy[:sin_family] = struct[:sin_family]
        copy[:sin_port] = struct[:sin_port]
        copy[:sin_addr] = struct[:sin_addr]
        copy
      end
    end

    class SockAddrIn6Struct < ::FFI::Struct
      layout :sin6_len, :uint8,
        :sin6_family, :sa_family_t,
        :sin6_port, :ushort,
        :sin6_flowinfo, :int,
        :sin6_addr, [:uint8, 16],
        :sin6_scope_id, :int

      def port_to_s
        Platforms.htons(self[:sin6_port])
      end

      def inspect
        "sin6_len [#{self[:sin6_len]}],
          sin6_family [#{self[:sin6_family]}],
          sin6_port [#{port_to_s}],
          sin6_addr [#{self[:sin6_addr]}],
          ip [#{to_ip}]"
      end

      def to_ip
        str = ::FFI::MemoryPointer.new(:string, Platforms::INET6_ADDRSTRLEN)
        # tricky; make a helper method to return a pointer to a struct's field
        # so we can abstract out this work
        sin_addr_ptr = Platforms.address_of(struct: self, field: :sin6_addr)
        hsh = Platforms::Functions.inet_ntop(self[:sin6_family], sin_addr_ptr, str, str.size)
        hsh[:rc]
      end

      def self.copy_to_new(struct)
        copy = SockAddrIn6Struct.new
        copy[:sin6_len] = struct[:sin6_len]
        copy[:sin6_family] = struct[:sin6_family]
        copy[:sin6_port] = struct[:sin6_port]
        copy[:sin6_flowinfo] = struct[:sin6_flowinfo]
        copy[:sin6_addr] = struct[:sin6_addr]
        copy[:sin6_scope_id] = struct[:sin6_scope_id]
        copy
      end
    end

    class SockAddrUnStruct < ::FFI::Struct
      layout :sun_len, :uint8,
        :sun_family, :sa_family_t,
        :sun_path, [:uint8, 104]

      def self.copy_to_new(struct)
        copy = self.class.new
        copy[:sun_len] = struct[:sun_len]
        copy[:sun_family] = struct[:sun_family]
        copy[:sun_path] = struct[:sun_path]
        copy
      end
    end

    AF_UNSPEC = PF_UNSPEC = 0
    AF_INET = PF_INET = 2
    AF_INET6 = PF_INET6 = 30
    AI_PASSIVE = 1
    SOCK_STREAM = 1
    SOCK_DGRAM = 2
    IPPROTO_TCP = 6
    IPPROTO_UDP = 17
    INET_ADDRSTRLEN = 16
    INET6_ADDRSTRLEN = 46
    SAE_ASSOCID_ANY = 0
    SAE_CONNID_ANY = 0

  end
end
