class IO
  module Internal
    # Convenience class for getting/setting fiber-local variables.
    class Fiber < ::Fiber
      include FiberLocalMixin

      def fid
        self.object_id
      end
    end
  end
end

module Kernel
  def fid
    Fiber.current.object_id
  end

  def tid
    cur = Thread.current
    id  = cur.object_id
    name = cur.local[:name]
    "#{id}-#{name}"
  end
end
