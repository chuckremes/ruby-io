class IO
  module Platforms
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

      #
      # Socket related
      #
      AF_INET6          = PF_INET6    = 10

      SOL_SOCKET        = 1
      SO_ERROR          = 4
      
    end
  end
end
