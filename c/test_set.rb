require 'set'

set1 = SortedSet[1, 2]

set2 = set1.dup

puts "expect different objects, [#{set1.object_id != set2.object_id}]"

puts "expect same contents, [#{set1 == set2}]"

puts "expect same length, [#{set1.size == set2.size}]"

puts "expect same to_a, [#{set1.to_a == set2.to_a}]"

