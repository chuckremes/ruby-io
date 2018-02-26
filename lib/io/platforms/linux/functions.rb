class IO
  module Platforms
    module Functions

      begin
        attach_function :epoll_create1,   [:int],                       :int, :blocking => true
        attach_function :epoll_ctl,       [:int, :int, :int, :pointer], :int, :blocking => true
        attach_function :epoll_wait,      [:int, :pointer, :int, :int], :int, :blocking => true
      rescue ::FFI::NotFoundError
        # fall back to select(2)
        require_relative '../common/select_poller'
      end
      
    end
  end
end
