require 'io'

RSpec.describe IO::Async do
  describe '#open' do
    let (:path) { '/tmp/t' }
    
    it 'succeeds' do
      io = IO::Async::File.open(path: path, flags: nil)
      expect(io.to_i).to eq 7 # 7 is usually the first FD assigned in a new process
    end
  end

  it 'tests nothing' do
    a = true
    expect(a).to be_truthy
  end
end
