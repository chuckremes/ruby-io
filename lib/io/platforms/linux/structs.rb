class IO
  module Platforms
    module Structs
      
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
      # Network
      #

      def self.address_of(struct:, field:)
        ::FFI::Pointer.new(:uint8, struct.pointer.address + struct.offset_of(field))
      end

      module AddrInfoStructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :ai_flags,      :int,
              :ai_family,     :int,
              :ai_socktype,   :int,
              :ai_protocol,   :int,
              :ai_addrlen,    :int,
              :ai_addr,       :pointer, # in linux, they are ordered as ai_addr and ai_canonname
              :ai_canonname,  :pointer, # in BSD, these fields are ordered as ai_canonname and ai_addr
              :ai_next,       :pointer
          end
        end
      end

      class IfAddrsStruct < ::FFI::Struct
        layout \
          :ifa_next, :pointer,
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
          [self[:sa_len], self[:sa_family], self[:sa_data].to_s]
        end
      end

      module SockAddrStorageStructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :ss_family, :sa_family_t,
              :ss_data,   [:uint8, 126]
          end
        end
      end

      module SockAddrInStructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :sin_family,  :sa_family_t,
              :sin_port,    :ushort,
              :sin_addr,    :uint32,
              :sin_zero,    [:uint8, 8]
          end
        end
      end

      module SockAddrIn6StructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :sin6_family,   :sa_family_t,
              :sin6_port,     :ushort,
              :sin6_flowinfo, :int,
              :sin6_addr,     [:uint8, 16],
              :sin6_scope_id, :int
          end
        end
      end

      module SockAddrUnStructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :sun_family,  :sa_family_t,
              :sun_path,    [:uint8, 104]
          end
        end
      end

    end
  end
end
