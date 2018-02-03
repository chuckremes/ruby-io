class IO
  module Internal
    # Convenience class for getting/setting fiber-local variables.
    class Fiber < ::Fiber
      include FiberLocalMixin

      def fid
        unless @fid
          cur = self
          unless cur.respond_to?(:local)
            cur.extend(IO::Internal::FiberLocalMixin)
            cur.local[:name] = "POOL?" if cur.local.safe?
          end
          id = cur.hash
          @fid = if cur.local.safe?
            "#{id}-#{cur.local[:name]}"
          else
            "#{id}-unsafe-access"
          end
        end
        @fid
      end
    end
  end
end

module Kernel
  def fid
    cur = Fiber.current
    unless cur.respond_to?(:local)
      Fiber.current.extend(IO::Internal::FiberLocalMixin)
      cur.local[:name] = "POOL?" if cur.local.safe?
    end
    id = cur.hash
    if cur.local.safe?
      "#{id}-#{cur.local[:name]}"
    else
      "#{id}-unsafe-access"
    end
  end

  def tid
    cur = Thread.current
    unless cur.respond_to?(:local)
      Thread.current.extend(IO::Internal::ThreadLocalMixin)
      cur.local[:name] = "POOL?"
    end
    id  = cur.hash
    if cur.local.safe?
      "#{id}-#{cur.local[:name]}"
    else
      "#{id}-unsafe-access"
    end
  end
end
