require 'benchmark/ips'
require 'ffi'

class E
  def read(a, b, c, d)
    #Time.at(a.to_f + b.to_f + c.to_f + d.to_f)
  end
end
none_one_level = E.new

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 15, :warmup => 5)


  x.report("method invocations") do |times|
    i = 0
    while i < times
      none_one_level.read(nil, nil, nil, nil)
      i += 1
    end
  end

  x.report("FFI::MemoryPointer.new(5)") do |times|
    i = 0
    while i < times
      FFI::MemoryPointer.new(5)
      i += 1
    end
  end

  x.report("FFI::MemoryPointer.new(4096)") do |times|
    i = 0
    while i < times
      FFI::MemoryPointer.new(4096)
      i += 1
    end
  end

  x.report("FFI::MemoryPointer.new(5).read_string") do |times|
    i = 0
    ptr = FFI::MemoryPointer.new(5)
    while i < times
      ptr.read_string
      i += 1
    end
  end

  x.report("FFI::MemoryPointer.new(4096).read_string") do |times|
    i = 0
    ptr = FFI::MemoryPointer.new(4096)
    while i < times
      ptr.read_string
      i += 1
    end
  end



  # Compare the iterations per second of the various reports!
  x.compare!
end
