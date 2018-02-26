class IO
  module Platforms
    module Functions

      begin
        attach_function :kqueue,      [],                                               :int, :blocking => true
        attach_function :kevent,      [:int, :pointer, :int, :pointer, :int, :pointer], :int, :blocking => true

        attach_function :disconnectx, [:int, :int, :int],                               :int, :blocking => true

      rescue ::FFI::NotFoundError
        # fallback to using select(2)
        require_relative '../common/poller'
      end

    end
  end
end
