# This file should be included *before* internal/fiber
class IO
  module Internal
    # The Ruby Thread API has a terrible naming convention for accessing
    # thread local variables and fiber local variables. This sets the world
    # right again by adding a #local instance method. This returns a hash
    # intended for storing whatever we need using the usual hash methods.
    class Thread < ::Thread
      include LocalMixin
    end
  end
end
