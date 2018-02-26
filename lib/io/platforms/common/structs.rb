class IO
  module Platforms
    module Structs

      #
      # Time
      #

      class TimeValStruct < ::FFI::Struct
        layout \
          :tv_sec, :time_t,
          :tv_usec, :int32

        def inspect
          "tv_sec [#{self[:tv_sec].inspect}], tv_usec [#{self[:tv_usec].inspect}]"
        end
      end

    end
  end
end
