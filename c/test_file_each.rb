$: << '../lib'
require 'io'

string = '0123456789abcdefghij'
string += '012'

flags = IO::Config::Flags.new
# No need to make FD nonblocking for File writes. It's pointless. Get shunted
# to worker thread. select/epoll/kqueue always signal that a block device is
# ready for reads and writes.
io = IO::Sync::File.open(path: '/tmp/t', flags: flags.create.readwrite.truncate)
#io.extend(IO::Mixins::Enumerable)

p io.write(string: string, offset: 0)
#p io.read(nbytes: 4000, offset: 0)
i = 0
io.each(limit: 5) do |rc, errno, str, new_offset|
  raise "read error, rc [#{rc}], errno [#{errno}]" if rc < 0
  i += 1

  if i == 3
    addition = 'ABCDE'
    rc, errno, offset = io.write(string: addition, offset: string.size)
    puts "WROTE / appended [#{addition.size}] bytes to offset [#{string.size}], rc [#{rc}], errno [#{errno}], offset [#{offset}]"
  end
  # if bytes read is 0, then we hit EOF and this block will exit before next iteration
  puts "[#{str}], string bytes [#{str.bytesize}], bytes read [#{rc}]"
end

puts "io.close => #{io.close.inspect}"

puts "exiting..."
