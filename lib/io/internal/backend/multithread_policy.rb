class IO
  module Internal
    module Backend
      module MultithreadPolicy
        class Silent
          def self.check(io:, creator:, current:)
            true
          end
        end
        
        class Warn
          WARNING = 'WARNING: It is NOT recommened to call IO objects from multiple threads!'
          def self.check(io:, creator:, current: Thread.current)
            return true if creator == current
            
            STDERR.puts WARNING
            string = "IO object #{io.inspect}\n"
            string += "Created in thread #{creator.inspect}\n"
            string += "Called by thread #{current.inspect}\n"
            true
          end
        end
        
        class Fatal
          def self.check(io:, creator:, current: Thread.current)
            return true if creator == current
            
            # FIXME: Use correct exception here
            raise "Thread #{creator.inspect} created IO object #{io.inspect} but called from other thread #{current.inspect}"
          ensure
            exit!(255)
          end
        end
      end
    end
  end
end
