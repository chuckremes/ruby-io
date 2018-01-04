require 'set'

class IO
  module Platforms
    module Common

      # Manages the addition and cancellation of all timers.
      #
      class Timers
        include Enumerable

        # Returns the current time using the following algo:
        #
        #  (Time.now.to_f * 1000).to_i
        #
        # Added as a class method so that it can be overridden by a user
        # who wants to provide their own time source. For example, a user
        # could use a third-party gem that provides a better performing
        # time source.
        #
        def self.now
          (Time.now.to_f * 1000).to_i
        end

        # Convert Timers.now to a number usable by the Time class.
        #
        def self.now_converted
          now / 1000.0
        end

        def initialize
          @timers = SortedSet.new

          @last_fired = Timers.now
        end

        def each
          @timers.each { |timer| yield(timer) }
        end

        # Returns the number of milliseconds until next timer
        # should fire. If it's in the past, then return 0.
        def wait_interval
          timer = @timers.first
          return 0 unless timer

          delay = timer.fire_time - Timers.now
          delay < 0 ? 0 : delay
        end

        # Adds a non-periodical, one-shot timer in order of
        # first-to-fire to last-to-fire.
        #
        # Returns nil unless a +timer_proc+ is
        # provided. There is no point to an empty timer that
        # does nothing when fired.
        #
        def add_oneshot(delay:, callback:)
          return nil unless callback

          timer = Timer.new(timers: self, delay: delay, callback: callback)
          add timer
          timer
        end

        # Cancel the +timer+.
        #
        # Returns +true+ when cancellation succeeds.
        # Returns +false+ when it fails to find the
        # given +timer+.
        #
        def cancel(timer)
          @timers.delete?(timer)
        end

        # A convenience method that loops through all known timers
        # and fires all of the expired timers.
        #
        def fire_expired
          # all time is expected as milliseconds
          now = Timers.now

          # detect when the clock has reversed
          reschedule if now < @last_fired
          @last_fired = now

          # defer firing the timer until after this loop so we can clean it up first
          @timers.dup.each do |timer|
            break unless timer.expired?(now)
            timer.fire
            cancel(timer)
          end
        end

        # Runs through all timers and asks each one to reschedule itself
        # from Timers.now + whatever delay was originally recorded.
        #
        def reschedule
          timers = @timers.dup
          @timers.clear

          timers.each do |timer|
            timer.reschedule
            add timer
          end
        end


        private

        def add timer
          @timers.add(timer)
        end
      end # class Timers


      # Used to track the specific expiration time and execution
      # code for each timer.
      #
      class Timer
        include Comparable

        attr_reader :fire_time, :timer_proc

        # +delay+ is in milliseconds
        #
        def initialize(timers:, delay:, callback:)
          @timers = timers
          @delay = delay
          @callback = callback
          reschedule
        end

        # Executes the callback.
        #
        # Returns +true+ when the timer is a one-shot;
        # Returns +false+ when the timer is periodical and has rescheduled
        # itself.
        #
        def fire
          @callback.call
        end

        # Cancels this timer from firing.
        #
        def cancel
          @timers.cancel self
        end

        def <=>(other)
          @fire_time <=> other.fire_time
        end

        def ==(other)
          # need a more specific equivalence test since multiple timers could be
          # scheduled to go off at exactly the same time
          #      @fire_time == other.fire_time &&
          #      @timer_proc == other.timer_proc &&
          #      @periodical == other.periodical?
          object_id == other.object_id
        end

        # True when the timer should be fired; false otherwise.
        #
        def expired?(time = Timers.now)
          time >= @fire_time
        end

        def reschedule(now: Timers.now)
          @fire_time = now + @delay
        end

        def to_s
          ftime = Time.at(@fire_time / 1000)
          fdelay = @fire_time - Timers.now
          name = @callback.respond_to?(:name) ? @callback.name : @callback.to_s

          "[delay [#{@delay}], periodical? [#{@periodical}], fire_time [#{ftime}] fire_delay_ms [#{fdelay}]] proc [#{name}]"
        end

        def inspect; to_s; end
      end # class Timer

    end
  end
end