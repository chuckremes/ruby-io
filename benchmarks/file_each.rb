
$: << File.join(File.dirname(__FILE__), '../lib')
require 'io'
require 'benchmark/ips'

# Setup test file on filesystem outside timing
file_path = File.join(File.dirname(__FILE__), 'fixtures', 'ascii_0_9_small.txt')
flags = IO::Config::Flags.new
sync_io_unbuffered = IO::Sync::File.open(
  path: file_path,
  flags: flags.readonly
)
sync_io_unbuffered.extend(IO::Mixins::UnbufferedEnumerable)

sync_io_buffered = IO::Sync::File.open(
  path: file_path,
  flags: flags.readonly
)
sync_io_buffered.extend(IO::Mixins::Enumerable)

async_io_unbuffered = IO::Async::File.open(
  path: file_path,
  flags: flags.readonly
)
async_io_unbuffered.extend(IO::Mixins::UnbufferedEnumerable)

async_io_buffered = IO::Async::File.open(
  path: file_path,
  flags: flags.readonly
)
async_io_buffered.extend(IO::Mixins::Enumerable)

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
