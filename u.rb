require 'fiber'

fC = nil

fA = Fiber.new do |f2|
  f2.transfer Fiber.current
  f3 = fC.transfer Fiber.current
  while true
    puts "A"
    f2.transfer(f3)
  end
end

fB = Fiber.new do |f1|
  f3 = f1.transfer
  while true
    puts "B"
    f3.transfer
  end
end

fC = Fiber.new do |f1|
  i = 0
  f1.transfer(Fiber.current)
  while true
    puts 'C'
    i += 1
    if i > 30
      p caller
      exit!
    else
      f1.transfer
    end
  end
end

fA.resume fB

