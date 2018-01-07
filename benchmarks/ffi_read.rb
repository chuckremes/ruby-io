require 'benchmark/ips'
require 'ffi'

module Platforms
  extend ::FFI::Library
  ffi_lib ::FFI::Library::LIBC

  attach_function :open, [:pointer, :int, :int], :int, :blocking => true
  attach_function :read, [:int, :pointer, :size_t], :ssize_t, :blocking => true
  attach_function :pread, [:int, :pointer, :size_t, :off_t], :ssize_t, :blocking => true
end

class E
  def initialize(path)
    @fd = Platforms.open(path, 0, 0)
  end
  
  def other(a, b, c, d)
    
  end
end

class Eread < E
  def read(buffer, nbytes)
    rc = Platforms.read(@fd, buffer, nbytes)
    errno = rc < 0 ? ::FFI.errno : nil
    rc
  end
end

class Epread < E
  def read(buffer, nbytes, offset)
    rc = Platforms.pread(@fd, buffer, nbytes, offset)
    errno = rc < 0 ? ::FFI.errno : nil
    {rc: rc, errno: errno}
  end
end

class Epreadblock < Epread
  def read(buffer, nbytes, offset)
    rc, errno = inablock do
      reply = super
      [reply[:rc], reply[:errno]]
    end
    [rc, errno]
  end
  
  def inablock
    yield
  end
end

eread = Eread.new('./t')
epread = Epread.new('./t')
epreadblock = Epreadblock.new('./t')
none_one_level = E.new('./doesnotexist')

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 15, :warmup => 5)


  x.report("method invocations") do |times|
    i = 0
    while i < times
      none_one_level.other(nil, nil, nil, nil)
      i += 1
    end
  end

  x.report("read(2), 5 bytes") do |times|
    i = 0
    ptr_size = 5
    ptr = FFI::MemoryPointer.new(ptr_size)
    while i < times
      eread.read(ptr, ptr_size)
      i += 1
    end
  end

  x.report("read(2), 4096 bytes") do |times|
    i = 0
    ptr_size = 4096
    ptr = FFI::MemoryPointer.new(ptr_size)
    while i < times
      eread.read(ptr, ptr_size)
      i += 1
    end
  end

  x.report("pread(2), 5 bytes") do |times|
    i = 0
    offset = 0
    ptr_size = 5
    ptr = FFI::MemoryPointer.new(ptr_size)
    while i < times
      reply = epread.read(ptr, ptr_size, offset)
      offset += reply[:rc]
      offset = 0 if offset > 4090
      i += 1
    end
  end

  x.report("pread(2), 4096 bytes") do |times|
    i = 0
    offset = 0
    ptr_size = 4096
    ptr = FFI::MemoryPointer.new(ptr_size)
    while i < times
      reply = epread.read(ptr, ptr_size, offset)
      offset += reply[:rc]
      offset = 0 if offset > 4090
      i += 1
    end
  end

  x.report("pread(2), 5 bytes, block") do |times|
    i = 0
    offset = 0
    ptr_size = 5
    ptr = FFI::MemoryPointer.new(ptr_size)
    while i < times
      rc, errno = epreadblock.read(ptr, ptr_size, offset)
      offset += rc
      offset = 0 if offset > 4090
      i += 1
    end
  end

  x.report("pread(2), 4096 bytes, block") do |times|
    i = 0
    offset = 0
    ptr_size = 4096
    ptr = FFI::MemoryPointer.new(ptr_size)
    while i < times
      rc, errno = epreadblock.read(ptr, ptr_size, offset)
      offset += rc
      offset = 0 if offset > 4090
      i += 1
    end
  end


  # Compare the iterations per second of the various reports!
  x.compare!
end
