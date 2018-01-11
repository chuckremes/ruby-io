$: << '../lib'
require 'io'

file_path = File.join(File.dirname(__FILE__), '..', 'benchmarks', 'fixtures', 'ascii_0_9_small.txt')

flags = IO::Config::Flags.new
# No need to make FD nonblocking for File writes. It's pointless. Get shunted
# to worker thread. select/epoll/kqueue always signal that a block device is
# ready for reads and writes.
io = IO::Sync::File.open(path: file_path, flags: flags.readonly)

i = 0
io.each(limit: 5) do |rc, errno, str, new_offset|
  raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
  i += 1

  # if bytes read is 0, then we hit EOF and this block will exit before next iteration
  puts "[#{str}], string bytes [#{str.bytesize}], bytes read [#{rc}], offset [#{new_offset}]"
end

puts "io.close => #{io.close.inspect}"

puts "exiting..."
