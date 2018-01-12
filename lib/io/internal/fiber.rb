class IO
  module Internal
    # Convenience class for getting/setting fiber-local variables.
    class Fiber < ::Fiber
      include FiberLocalMixin
    end
  end
end
