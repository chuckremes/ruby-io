require 'benchmark/ips'

class Ak
  def initialize(to:)
    @to = to
  end

  def read(a:, b:, c:, d: nil)
    @to.read(a: a, b: b, c: c, d: d)
  end
end

class Bk
  def initialize(to:)
    @to = to
  end
  
  def read(a:, b:, c:, d: nil)
    @to.read(a, b, c, d)
  end
end

class A
  def initialize(to)
    @to = to
  end

  def read(a, b, c, d=nil)
    @to.read(a, b, c, d)
  end
end

class E
  def read(a, b, c, d)
    #Time.at(a.to_f + b.to_f + c.to_f + d.to_f)
  end
end

class Ek
  def read(a:, b:, c:, d:)
    #Time.at(a.to_f + b.to_f + c.to_f + d.to_f)
  end
end

with_words = Ak.new(to: Ak.new(to: Ak.new(to: Bk.new(to: E.new))))
no_words = A.new(A.new(A.new(A.new(E.new))))
none_one_level = E.new
keys_one_level = Ek.new

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 15, :warmup => 5)


  x.report("keywords") do |times|
    i = 0
    while i < times
      with_words.read(a: 3, b: 3**7.5, c: (3**7.5 % 3))
      i += 1
    end
  end

  x.report("keywords, 1-level deep") do |times|
    i = 0
    while i < times
      keys_one_level.read(a: 3, b: 3**7.5, c: (3**7.5 % 3), d: nil)
      i += 1
    end
  end

  x.report("nokeywords") do |times|
    i = 0
    while i < times
      no_words.read(3, 3**7.5, (3**7.5 % 3))
      i += 1
    end
  end

  x.report("nokeywords, 1-level deep") do |times|
    i = 0
    while i < times
      none_one_level.read(3, 3**7.5, (3**7.5 % 3), nil)
      i += 1
    end
  end



  # Compare the iterations per second of the various reports!
  x.compare!
end
