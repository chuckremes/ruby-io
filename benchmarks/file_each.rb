
$: << File.join(File.dirname(__FILE__), '../lib')
require 'io'
require 'benchmark/ips'

# Setup test file on filesystem outside timing
file_path = File.join(File.dirname(__FILE__), 'fixtures', 'ascii_0_9_small.txt')
flags = IO::Config::Flags.new

sync_io_unbuffered = nil
IO::Config::Defaults.syscall_mode_switch(mode: :blocking) do
  sync_io_unbuffered = IO::File.open(
    path: file_path,
    flags: flags.readonly
  )
  sync_io_unbuffered.extend(IO::Mixins::UnbufferedEnumerable)
end

sync_io_buffered = nil
IO::Config::Defaults.syscall_mode_switch(mode: :blocking) do
  sync_io_buffered = IO::File.open(
    path: file_path,
    flags: flags.readonly
  )
  sync_io_buffered.extend(IO::Mixins::Enumerable)
end

async_io_unbuffered = nil
IO::Config::Defaults.syscall_mode_switch(mode: :nonblocking) do
  async_io_unbuffered = IO::File.open(
    path: file_path,
    flags: flags.readonly
  )
  async_io_unbuffered.extend(IO::Mixins::UnbufferedEnumerable)
end

async_io_buffered = nil
IO::Config::Defaults.syscall_mode_switch(mode: :nonblocking) do
  async_io_buffered = IO::File.open(
    path: file_path,
    flags: flags.readonly
  )
  async_io_buffered.extend(IO::Mixins::Enumerable)
end

regular_ruby = File.open(
  file_path,
  'r'
)

newio_iterations = 0
newio_times = 0
nativeio_iterations = 0
nativeio_times = 0

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 15, :warmup => 5)


  x.report("sync each, buffered") do |times|
    newio_times += times
    i = 0
    while i < times
      sync_io_buffered.each(limit: 5) do |rc, errno, str, offset|
        # no op
        newio_iterations += 1
      end
      i += 1
    end
  end

  x.report("sync each, unbuffered") do |times|
    i = 0
    while i < times
      sync_io_unbuffered.each(limit: 5) do |rc, errno, str, offset|
        raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
        # no op
      end
      i += 1
    end
  end

  x.report("async each, buffered") do |times|
    i = 0
    while i < times
      async_io_buffered.each(limit: 5) do |rc, errno, str, offset|
        raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
        # no op
      end
      i += 1
    end
  end

  x.report("async each, unbuffered") do |times|
    i = 0
    while i < times
      async_io_buffered.each(limit: 5) do |rc, errno, str, offset|
        raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
        # no op
      end
      i += 1
    end
  end

  #  x.report("sync each, native IO") do |times|
  #    nativeio_times += times
  #    i = 0
  #    while i < times
  #      regular_ruby.rewind
  #      regular_ruby.each(5) do |line|
  #        nativeio_iterations += 1
  #        raise "read error, regular ruby" if line.size < 0
  #        # no op
  #      end
  #      i += 1
  #    end
  #  end

  # Compare the iterations per second of the various reports!
  x.compare!
end

puts "newio_iterations [#{newio_iterations}], nativeio_iterations [#{nativeio_iterations}]"
puts "newio_times [#{newio_times}], nativeio_times [#{nativeio_times}]"
