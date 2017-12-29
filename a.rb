Thread.abort_on_exception = true

t = Thread.new do
  raise 'Should propogate to main thread'
end

sleep 1

