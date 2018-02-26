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
      AI_PASSIVE = 1

      SOL_SOCKET = 0xffff
      SO_ERROR   = 0x1007
    end
  end
end
