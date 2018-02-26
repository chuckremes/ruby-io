class IO
  module POSIX

    AI_PASSIVE                = Platforms::Constants::AI_PASSIVE
    AF_UNSPEC   = PF_UNSPEC   = Platforms::Constants::AF_UNSPEC
    AF_INET     = PF_INET     = Platforms::Constants::AF_INET
    AF_INET6    = PF_INET6    = Platforms::Constants::AF_INET6

    INET_ADDRSTRLEN           = Platforms::Constants::INET_ADDRSTRLEN
    INET6_ADDRSTRLEN          = Platforms::Constants::INET6_ADDRSTRLEN

    SOCK_STREAM = Platforms::Constants::SOCK_STREAM
    SOCK_DGRAM  = Platforms::Constants::SOCK_DGRAM


    SOL_SOCKET = Platforms::Constants::SOL_SOCKET
    SO_ERROR   = Platforms::Constants::SO_ERROR
  end
end
