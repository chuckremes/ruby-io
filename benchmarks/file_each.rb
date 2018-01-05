$: << '../lib'
require 'io'
require 'benchmark/ips'

# Setup test file on filesystem outside timing
string = '0123456789' * 1024 * 4

flags = IO::Config::Flags.new
io = IO::Sync::File.open(path: '/tmp/t', flags: flags.create.readwrite.truncate)

io.write(string: string, offset: 0)

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 15, :warmup => 3)


  x.report("each, buffered") do |times|
    io.extend(IO::Mixins::BufferedEnumerable)

    i = 0
    while i < times
      io.each(limit: 5) do |str, rc, errno|
        raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
        # no op
      end
      i += 1
    end
  end


  x.report("each, unbuffered") do |times|
    io.extend(IO::Mixins::Enumerable)

    i = 0
    while i < times
      io.each(limit: 5) do |str, rc, errno|
        raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
        # no op
      end
      i += 1
    end
  end

  # Compare the iterations per second of the various reports!
  x.compare!
end
