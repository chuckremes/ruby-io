require 'forwardable'

class IO
  module Async
    module Private

      # Keeps track of all active fibers. Any fiber that has an outstanding
      # IO request will be recorded here.
      #
      # As requests are fulfilled (or timed out) and responses come back,
      # the IO Fiber can lookup the associated fiber and return the reply
      # to it.
      class Mapper
        extend Forwardable
        def_delegators :@storage, :[], :[]=, :key?

        def initialize
          @storage = {}
        end
      end
    end
  end
end
