class IO
  module Platforms
    module Structs

      #
      # Poller
      #

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

      #
      # Time
      #

      class TimeSpecStruct < ::FFI::Struct
        layout \
          :tv_sec, :long,
          :tv_nsec, :long

        def inspect
          "tv_sec [#{self[:tv_sec].inspect}], tv_nsec [#{self[:tv_nsec].inspect}]"
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
              :ai_canonname,  :pointer, # in BSD, these fields are ordered as ai_canonname and ai_addr
              :ai_addr,       :pointer,      # in linux, they are ordered as ai_addr and ai_canonname
              :ai_next,       :pointer
          end
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

      module SockAddrStorageStructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :ss_len,    :uint8,
              :ss_family, :sa_family_t,
              :ss_data,   [:uint8, 126]
          end
        end
      end

      class TimevalStruct < ::FFI::Struct
        layout :tv_sec, :time_t,
          :tv_usec, :suseconds_t
      end

      module SockAddrInStructLayout
        def self.included(base)
          base.class_eval do
            layout \
              :sin_len,     :uint8, # BSD platforms have this *_len field
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
              :sin6_len,      :uint8, # BSD platforms have this *_len field
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
              :sun_len,     :uint8,
              :sun_family,  :sa_family_t,
              :sun_path,    [:uint8, 104]
          end
        end
      end

    end
  end
end
