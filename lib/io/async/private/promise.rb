class IO
  module Async
    module Private
      # Can only be fulfilled once. Once fulfilled, the +reply+ is sent
      # directly back to the +mailbox+ given to the Promise initially.
      class Promise
        # Just a placeholder until we can leverage an Atomic reference
        # for MRI, Rubinius, JRuby, etc. May need to pull in concurrent-ruby
        # gem for now.
        class AtomicFlag
          def initialize(value)
            @value = value
          end

          def compare_and_set(oldval, newval)
            return false if oldval != @value
            @value = newval
            true
          end
        end

        def initialize(mailbox:)
          @mailbox = mailbox
          @cas = AtomicFlag.new(true)
        end
  
        def fulfill(reply)
          Logger.debug(klass: self.class, name: :fulfill, message: "reply #{reply.inspect}")
          if @cas.compare_and_set(true, false)
            Logger.debug(klass: self.class, name: :fulfill, message: "posting reply, seqno [#{reply[:_sequence_no_]}]")
            # We only get here if we are the first to set new value
            # Post reply directly to originating Fiber Scheduler's mailbox
            @mailbox.post(reply)
          else
            Logger.debug(klass: self.class, name: :fulfill, message: 'could not post reply, someone fulfilled before me')            
          end
        end
      end
    end
  end
end
