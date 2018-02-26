class IO
  module Platforms
    module Constants

      #
      # Typedefs
      #
      typedef :long,   :uintptr_t
      typedef :long,   :intptr_t


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


      AF_UNSPEC   = PF_UNSPEC   = 0
      AF_INET     = PF_INET     = 2
      AF_INET6    = PF_INET6    = 30

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
end
