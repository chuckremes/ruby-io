require 'fiber' # pull in Fiber.current and Fiber#transfer

Thread.abort_on_exception = true
DEBUG = false

class IO
  class Logger
    def self.debug(klass:, name:, message:)
      return unless DEBUG
      thr_id = Thread.current.object_id
      string = "[#{thr_id}], #{klass}##{name}, #{message}"
      STDERR.puts(string)
    end
  end
end

# shared
require_relative 'io/internal/local'
require_relative 'io/internal/fiber'
require_relative 'io/internal/thread'
require_relative 'io/internal/backend/error_policy'
require_relative 'io/internal/backend/multithread_policy'

require_relative 'io/platforms/common_constants'
require_relative 'io/platforms/common_ffi'
require_relative 'io/platforms/functions'
require_relative 'io/config/defaults'
require_relative 'io/config/flags'
require_relative 'io/config/mode'

require_relative 'io/mixins/enumerable'

# sync
require_relative 'io/internal/backend/sync'
require_relative 'io/sync/fcntl'
require_relative 'io/sync/file'
require_relative 'io/sync/tcp'

# async
require_relative 'io/internal/backend/async'
require_relative 'io/async/private/private'
require_relative 'io/async/timer'
require_relative 'io/async/fcntl'
require_relative 'io/async/file'
require_relative 'io/async/tcp'
