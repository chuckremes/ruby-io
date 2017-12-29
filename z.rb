require 'fiber'

begin
  Fiber.new { Fiber.yield Fiber.current }.transfer.resume
  puts "Cool I'm in ruby 1.9.x. I've got fibers!"
rescue FiberError
  puts "Too bad, I'm in 2.x and no transfer/yield/resume for me. Is it supposed to be a feature? :("
end

