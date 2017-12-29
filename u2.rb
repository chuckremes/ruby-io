require 'fiber'

class A
  def initialize
    @fiber = Fiber.new do |fiber|
      fiber.transfer(Fiber.current)
      while true
        callme(fiber)
      end
    end
  end

  def callme(fiber)
    puts 'A'
    transferit(fiber)
  end

  def transferit(fiber)
    fiber.transfer
  end

  def start(other)
    @fiber.resume(other.fiber)
  end
end

class B
  attr_reader :fiber
  
  def initialize
    @fiber = Fiber.new do |fiber|
      @i = 0
      fiber.transfer
      while true
        callme(fiber)
        @i += 1
      end
    end
  end

  def callme(fiber)
    puts 'B'
    transferit(fiber)
  end

  def transferit(fiber)
    fiber.transfer
    if @i > 30
      p caller
      exit!
    end
  end
end

f1 = Fiber.new do |f2|
  f2.transfer Fiber.current
  while true
    puts "A"
    f2.transfer
  end
end

f2 = Fiber.new do |f1|
  i = 0
  f1.transfer
  while true
    puts "B"
    i += 1
    f1.transfer
    if i > 30
      p caller[0]
      exit!
    end
  end
end

#f1.resume f2

a = A.new
b = B.new
a.start(b)
