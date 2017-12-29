class IO
  module Internal
    # Convenience class for getting/setting fiber-local variables.
    class Fiber < ::Fiber
      include LocalMixin
    end
  end
end
