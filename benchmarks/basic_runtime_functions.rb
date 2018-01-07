require 'benchmark/ips'


class E
  def read(a, b, c, d)
    #Time.at(a.to_f + b.to_f + c.to_f + d.to_f)
  end
  
  def yield_block
    yield
  end
  
  def call_block(&blk)
    blk.call
  end
  
  def yield_block_with_keywords(limit:, offset:0, timeout: nil, &blk)
    yield
  end
  
  def yield_block_with_keywords_block_arg(limit:, offset:0, timeout: nil, &blk)
    yield(nil)
  end
  
  def yield_block_with_keywords_block_arg_loop(limit:, offset:0, timeout: nil, &blk)
    i = 0
    while i < 10#_000
      yield(i)
      i += 1
    end
  end
end

basic = E.new

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(:time => 15, :warmup => 5)


  x.report("method invocations") do |times|
    i = 0
    while i < times
      basic.read(nil, nil, nil, nil)
      i += 1
    end
  end

  x.report("yield invocations") do |times|
    i = 0
    while i < times
      basic.yield_block {}
      i += 1
    end
  end

  x.report("block invocations") do |times|
    i = 0
    while i < times
      basic.call_block {}
      i += 1
    end
  end

  x.report("yield w/keywords invocations") do |times|
    i = 0
    while i < times
      basic.yield_block_with_keywords(limit: 5) do
        
      end
      i += 1
    end
  end

  x.report("yield w/keywords and block arg invocations") do |times|
    i = 0
    while i < times
      basic.yield_block_with_keywords_block_arg(limit: 5) do |str|
        
      end
      i += 1
    end
  end

  x.report("yield w/keywords and block arg and loop invocations") do |times|
    i = 0
    while i < times
      basic.yield_block_with_keywords_block_arg_loop(limit: 5) do |str|
        
      end
      i += 1
    end
  end

  # Compare the iterations per second of the various reports!
  x.compare!
end
