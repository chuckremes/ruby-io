fiber2 = nil

fiber1 = Fiber.new do
  puts "In Fiber 1"                 # 3
  fiber2.transfer                   # 4
end

fiber2 = Fiber.new do
  puts "In Fiber 2"                  # 1
  fiber1.transfer                    # 2
  puts "In Fiber 2 again"            # 5
  Fiber.yield                        # 6
  puts "Fiber 2 resumed"             # 10
end

fiber3 = Fiber.new do
  puts "In Fiber 3"                  # 8
end

fiber2.resume                        # 0
fiber3.resume                        # 7
fiber2.resume                        # 9

