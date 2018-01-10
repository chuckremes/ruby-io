$: << '../lib'
require 'io'

flags = IO::Config::Flags.new
# No need to make FD nonblocking for File writes. It's pointless. Get shunted
# to worker thread. select/epoll/kqueue always signal that a block device is
# ready for reads and writes.
io = IO::Sync::File.open(
  path: File.join(File.dirname(__FILE__), '..', 'benchmarks', 'fixtures', '0_to_255_utf8.txt'),
  flags: flags.create.readonly
)

tio = IO::Transcode.choose_for(encoding: Encoding::UTF_8, io: io)

tio.each(separator: ': ') do |rc, errno, str, new_offset|
  raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0

  puts str.inspect, str.encoding
  puts "string bytes [#{str.bytesize}], bytes read [#{rc}]"
end

puts '----------------------------------------'


tio.each(limit: 50, separator: nil) do |rc, errno, str, new_offset|
  raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0

  puts str.inspect, str.encoding
end

puts "io.close => #{io.close.inspect}"

puts "exiting..."
