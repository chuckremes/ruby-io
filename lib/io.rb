require 'fiber' # pull in Fiber.current and Fiber#transfer
require 'set' # load set early and create a SortedSet to work around a Rubinius issue
# still investigating...
s = SortedSet.new

Thread.abort_on_exception = true
DEBUG = false

class IO
  class Logger
    def self.debug(klass:, name:, message:, force: false)
      return unless DEBUG || force
      thr_id = Thread.current.hash
      fib_id = Fiber.current.hash
      time = formatted_time
      string = "[#{time}] | [#{thr_id} / #{fib_id}], #{klass}##{name}, #{message}"
      STDERR.puts(string)
    end

    def self.formatted_time
      Time.now.strftime "%Y-%m-%dT%H:%M:%S.%3N"
    end
  end
end

def elapsed(str)
  start = Time.now
  value = yield
  secs = Time.now - start
  puts "#{str}: [#{secs}] to finish."
  value
end

# shared
require_relative 'io/internal/local'
require_relative 'io/internal/fiber'
require_relative 'io/internal/thread'
require_relative 'io/internal/read_cache'
require_relative 'io/internal/backend/error_policy'
require_relative 'io/internal/backend/multithread_policy'

require_relative 'io/platforms/common_constants'
require_relative 'io/platforms/common_ffi'
require_relative 'io/platforms/functions'
require_relative 'io/platforms/constants'
require_relative 'io/platforms/structs'

# temporary loading order to satisfy defaults
require_relative 'io/internal/backend/async'
require_relative 'io/internal/backend/sync'

require_relative 'io/config/defaults'
require_relative 'io/config/flags'
require_relative 'io/config/mode'

require_relative 'io/mixins/enumerable'

require_relative 'io/fcntl'
require_relative 'io/file'
require_relative 'io/socket'
require_relative 'io/tcp'
require_relative 'io/timer'
require_relative 'io/udp'

require_relative 'io/async/private/private'

# transcoder
require_relative 'io/transcode/transcode'
require_relative 'io/transcode/each_readers/ascii_8bit'
require_relative 'io/transcode/each_readers/utf_8'
