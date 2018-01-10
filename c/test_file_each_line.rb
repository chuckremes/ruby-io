$: << '../lib'
require 'io'

flags = IO::Config::Flags.new
# No need to make FD nonblocking for File writes. It's pointless. Get shunted
# to worker thread. select/epoll/kqueue always signal that a block device is
# ready for reads and writes.
io = IO::Sync::File.open(
  path: File.join(File.dirname(__FILE__), '..', 'benchmarks', 'fixtures', 'numbered_lines.txt'),
  flags: flags.create.readonly
)

tio = IO::Transcode.choose_for(encoding: nil, io: io)

tio.each(separator: ': ') do |rc, errno, str, new_offset|
  raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0

  puts str.inspect
  puts "string bytes [#{str.bytesize}], bytes read [#{rc}]"
end

puts '----------------------------------------'

tio.each(limit: 5, separator: ':') do |rc, errno, str, new_offset|
  raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0

  puts str.inspect
  puts "string bytes [#{str.bytesize}], bytes read [#{rc}]"
end

puts "io.close => #{io.close.inspect}"

puts "exiting..."
