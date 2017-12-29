class IO
  class Policy
    class ReturnCode
      def self.check(reply)
        return reply if reply[:_return_code_].zero?

        # Got an error. Build a ReturnCodeError, populate it,
        # and return
        ReturnCodeError.new(reply)
      end

      class ReturnCodeError
        def initialize(reply)
          # Look up errno
          # Look up errstring
          # Save original reply
        end
      end
    end

    class Exceptional < StandardError
      def self.check(reply)
        return reply if reply[:_return_code].zero?

        # Got an error. Build an ExceptionalError, populate it,
        # and return
        error = Exceptional.create(reply)
        raise error
      end

      def self.create(reply)
        # some kind of case statement to figure out what error to
        # raise. Need to mimic the POSIX errors like EBADF, EINVAL,
        # etc.
        Exceptional.new(reply)
      end

      def initialize(reply)
        @return_code = ReturnCodeError.new(reply)
      end
    end

    def self.check(reply)
      @active_policy.check(reply)
    end

    def active_policy=(value)
      raise "Unknown policy type! [#{value}]" unless ReturnCode == value || Exceptional == value
      @active_policy = value
    end

    active_policy = Exceptional
  end
end
