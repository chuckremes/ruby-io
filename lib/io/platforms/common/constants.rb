class IO
  module Platforms
    module Constants
      #
      # Typedefs
      #
      typedef :int32,   :tv_sec

      #
      # Socket related
      #
      AF_UNSPEC         = PF_UNSPEC   = 0
      AF_LOCAL          = PF_LOCAL    = 1
      AF_INET           = PF_INET     = 2
      AI_PASSIVE        = 1
      SOCK_STREAM       = 1
      SOCK_DGRAM        = 2
      IPPROTO_TCP       = 6
      IPPROTO_UDP       = 17
      INET_ADDRSTRLEN   = 16
      INET6_ADDRSTRLEN  = 46
      SAE_ASSOCID_ANY   = 0
      SAE_CONNID_ANY    = 0

    end
  end
end
