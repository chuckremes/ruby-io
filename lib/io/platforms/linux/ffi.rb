class IO
  module Platforms
    AF_UNSPEC        = PF_UNSPEC = 0
    AF_LOCAL         = PF_LOCAL  = 1
    AF_INET          = PF_INET   = 2
    AF_INET6         = PF_INET6  = 10
    AI_PASSIVE       = 1
    SOCK_STREAM      = 1
    SOCK_DGRAM       = 2
    IPPROTO_TCP      = 6
    IPPROTO_UDP      = 17
    INET_ADDRSTRLEN  = 16
    INET6_ADDRSTRLEN = 46
    SAE_ASSOCID_ANY  = 0
    SAE_CONNID_ANY   = 0
    SOMAXCONN        = 128


    module Constants

      module SockOpt
        SOL_SOCKET = 1

        SO_ERROR   = 4
      end

      module SockFlags
        MSG_OOB    = 0x01
        MSG_PEEK   = 0x02
      end
    end

    #
    # Linux-specific functions
    #
    begin
      attach_function :epoll_create1, [:int], :int, :blocking => true
      attach_function :epoll_ctl, [:int, :int, :int, :pointer], :int, :blocking => true
      attach_function :epoll_wait, [:int, :pointer, :int, :int], :int, :blocking => true
    rescue ::FFI::NotFoundError
      # fall back to select(2)
      require_relative '../common/select_poller'
    end

    #           typedef union epoll_data {
    #               void    *ptr;
    #               int      fd;
    #               uint32_t u32;
    #               uint64_t u64;
    #           } epoll_data_t;
    #
    #           struct epoll_event {
    #               uint32_t     events;    /* Epoll events */
    #               epoll_data_t data;      /* User data variable */
    #           };                          /* this is a *packed* struct */
    class EPollDataUnion < FFI::Union
      layout \
        :fd,  :int,
        :u64, :uint64
    end

    class EPollEventStruct < FFI::Struct
      pack 1
      layout \
        :events, :uint32,
        :data, EPollDataUnion

      def self.setup(struct:, fd:, id:, events:)
        struct[:data][:fd] = fd if fd
        struct[:data][:u64] = id if id
        struct[:events] = events
      end

      def self.read?(struct:)
        (struct[:events] & Constants::EPOLLIN) != 0
      end

      def self.write?(struct:)
        (struct[:events] & Constants::EPOLLOUT) != 0
      end

      def self.empty?(struct:)
        struct[:events].zero?
      end

      def self.error?(struct:)
        (struct[:events] & Constants::EPOLLERR) != 0
      end

      def self.fd(struct:)
        struct[:data][:fd]
      end

      def self.id(struct:)
        struct[:data][:u64]
      end

      def setup(fd: nil, id: nil, events:)
        EPollEventStruct.setup(
          struct: self,
          fd: fd,
          id: id,
          events: events
        )
      end

      def read?
        EPollEventStruct.read?(struct: self)
      end

      def write?
        EPollEventStruct.write?(struct: self)
      end

      def empty?
        EPollEventStruct.empty?(struct: self)
      end

      def error?
        EPollEventStruct.error?(struct: self)
      end

      def fd
        EPollEventStruct.fd(struct: self)
      end

      def id
        EPollEventStruct.id(struct: self)
      end

      def inspect
        "events  [#{self[:events].to_s(2)}],
         data.fd [#{self[:data][:fd]}],
         data.id [#{self[:data][:u64]}]"
      end
    end

    #
    # Constants
    #
    module Constants
      EPOLLIN        = 0x001
      EPOLLPRI       = 0x002
      EPOLLOUT       = 0x004
      EPOLLRDNORM    = 0x040
      EPOLLRDBAND    = 0x080
      EPOLLWRNORM    = 0x100
      EPOLLWRBAND    = 0x200
      EPOLLMSG       = 0x400
      EPOLLERR       = 0x008
      EPOLLHUP       = 0x010
      EPOLLRDHUP     = 0x2000
      EPOLLEXCLUSIVE = 1 << 28
      EPOLLWAKEUP    = 1 << 29
      EPOLLONESHOT   = 1 << 30
      EPOLLET        = 1 << 31

      # Opcodes for epoll_ctl()
      EPOLL_CTL_ADD  = 1
      EPOLL_CTL_DEL  = 2
      EPOLL_CTL_MOD  = 3
    end

  end
end

class IO
  module Platforms

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
        :ai_addr, :pointer,
        :ai_canonname, :pointer,
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
      layout \
        :sa_family, :sa_family_t,
        :sa_data, [:uint8, 14]

      def inspect
        [self[:sa_family], self[:sa_data].to_s]
      end
    end

    class SockAddrStorageStruct < ::FFI::Struct
      layout \
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
      layout \
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
        "sin_family [#{self[:sin_family]}],
          sin_port [#{port_to_s}],
          sin_addr [#{self[:sin_addr]}],
          ip [#{to_ip}]"
      end

      def self.copy_to_new(struct)
        copy = SockAddrInStruct.new
        copy[:sin_family] = struct[:sin_family]
        copy[:sin_port] = struct[:sin_port]
        copy[:sin_addr] = struct[:sin_addr]
        copy
      end
    end

    class SockAddrIn6Struct < ::FFI::Struct
      layout \
        :sin6_family, :sa_family_t,
        :sin6_port, :ushort,
        :sin6_flowinfo, :int,
        :sin6_addr, [:uint8, 16],
        :sin6_scope_id, :int

      def port_to_s
        Platforms.htons(self[:sin6_port])
      end

      def inspect
        "sin6_family [#{self[:sin6_family]}],
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
        copy[:sin6_family] = struct[:sin6_family]
        copy[:sin6_port] = struct[:sin6_port]
        copy[:sin6_flowinfo] = struct[:sin6_flowinfo]
        copy[:sin6_addr] = struct[:sin6_addr]
        copy[:sin6_scope_id] = struct[:sin6_scope_id]
        copy
      end
    end

    class SockAddrUnStruct < ::FFI::Struct
      layout \
        :sun_family, :sa_family_t,
        :sun_path, [:uint8, 104]

      def self.copy_to_new(struct)
        copy = self.class.new
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
    IPPROTO_TCP = 6
    IPPROTO_UDP = 17
    INET_ADDRSTRLEN = 16
    INET6_ADDRSTRLEN = 46

  end
end
