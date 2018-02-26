require_relative 'functions'
require_relative 'constants'
require_relative 'structs'

require_relative 'epoll_poller'

class IO
  module Platforms

    #
    # Linux-specific functions
    #
#    begin
#      attach_function :epoll_create1, [:int], :int, :blocking => true
#      attach_function :epoll_ctl, [:int, :int, :int, :pointer], :int, :blocking => true
#      attach_function :epoll_wait, [:int, :pointer, :int, :int], :int, :blocking => true
#    rescue ::FFI::NotFoundError
#      # fall back to select(2)
#      require_relative '../common/select_poller'
#    end
#
#    #           typedef union epoll_data {
#    #               void    *ptr;
#    #               int      fd;
#    #               uint32_t u32;
#    #               uint64_t u64;
#    #           } epoll_data_t;
#    #
#    #           struct epoll_event {
#    #               uint32_t     events;    /* Epoll events */
#    #               epoll_data_t data;      /* User data variable */
#    #           };                          /* this is a *packed* struct */
#    class EPollDataUnion < FFI::Union
#      layout \
#        :fd,  :int,
#        :u64, :uint64
#    end
#
#    class EPollEventStruct < FFI::Struct
#      pack 1
#      layout \
#        :events, :uint32,
#        :data, EPollDataUnion
#
#      def self.setup(struct:, fd:, id:, events:)
#        struct[:data][:fd] = fd if fd
#        struct[:data][:u64] = id if id
#        struct[:events] = events
#      end
#
#      def self.read?(struct:)
#        (struct[:events] & Constants::EPOLLIN) != 0
#      end
#
#      def self.write?(struct:)
#        (struct[:events] & Constants::EPOLLOUT) != 0
#      end
#
#      def self.empty?(struct:)
#        struct[:events].zero?
#      end
#
#      def self.error?(struct:)
#        (struct[:events] & Constants::EPOLLERR) != 0
#      end
#
#      def self.fd(struct:)
#        struct[:data][:fd]
#      end
#
#      def self.id(struct:)
#        struct[:data][:u64]
#      end
#
#      def setup(fd: nil, id: nil, events:)
#        EPollEventStruct.setup(
#          struct: self,
#          fd: fd,
#          id: id,
#          events: events
#        )
#      end
#
#      def read?
#        EPollEventStruct.read?(struct: self)
#      end
#
#      def write?
#        EPollEventStruct.write?(struct: self)
#      end
#
#      def empty?
#        EPollEventStruct.empty?(struct: self)
#      end
#
#      def error?
#        EPollEventStruct.error?(struct: self)
#      end
#
#      def fd
#        EPollEventStruct.fd(struct: self)
#      end
#
#      def id
#        EPollEventStruct.id(struct: self)
#      end
#
#      def inspect
#        "events  [#{self[:events].to_s(2)}],
#         data.fd [#{self[:data][:fd]}],
#         data.id [#{self[:data][:u64]}]"
#      end
#    end
#
    #
    # Constants
    #
    module Constants
#      EPOLLIN        = 0x001
#      EPOLLPRI       = 0x002
#      EPOLLOUT       = 0x004
#      EPOLLRDNORM    = 0x040
#      EPOLLRDBAND    = 0x080
#      EPOLLWRNORM    = 0x100
#      EPOLLWRBAND    = 0x200
#      EPOLLMSG       = 0x400
#      EPOLLERR       = 0x008
#      EPOLLHUP       = 0x010
#      EPOLLRDHUP     = 0x2000
#      EPOLLEXCLUSIVE = 1 << 28
#      EPOLLWAKEUP    = 1 << 29
#      EPOLLONESHOT   = 1 << 30
#      EPOLLET        = 1 << 31
#
#      # Opcodes for epoll_ctl()
#      EPOLL_CTL_ADD  = 1
#      EPOLL_CTL_DEL  = 2
#      EPOLL_CTL_MOD  = 3
    end

  end
end
