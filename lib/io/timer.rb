class IO
  class Timer
    # Time is additive, so if given +seconds+, +milliseconds+, and
    # +nanoseconds+ then they will all be added together for a
    # total timeout.
    def self.sleep(seconds: 0, milliseconds: 0, nanoseconds: 0)
      Config::Defaults.syscall_backend.setup
      seconds = 2**30 if seconds.nil? || milliseconds.nil? || nanoseconds.nil?
      @timeout_ms = (seconds.to_i * 1_000) + milliseconds.to_i + (nanoseconds.to_i / 1_000)
      reply = Config::Defaults.syscall_backend.timer(duration: @timeout_ms)
      reply[:actual_duration]
    end
  end
end
