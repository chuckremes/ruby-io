class IO
  module Async
    module Private
      module Response

        class Wrapper
          attr_reader :object
          def initialize(object)
            @object = object
          end
        end
        
      end
    end
  end
end
