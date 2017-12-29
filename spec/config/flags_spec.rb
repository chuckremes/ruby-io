require 'io/platforms/common_constants'
require 'io/config/flags'

class IO
  module Config
    RSpec.describe Flags do
      it 'defaults to 0' do
        expect(Flags.new.to_i).to eq 0
      end

      describe '#readonly' do
        describe 'with single call' do
          it 'sets the RDONLY bit' do
            expect(Flags.new.readonly.to_i).to eq Platforms::Constants::O_RDONLY
          end
        end

        describe 'with multiple calls' do
          it 'sets the RDONLY bit' do
            expect(Flags.new.readonly.readonly.to_i).to eq Platforms::Constants::O_RDONLY
          end
        end

        describe 'where first call has true arg, second call has false arg' do
          it 'sets the RDONLY bit' do
            expect(Flags.new.readonly.readonly(false).to_i).to eq Platforms::Constants::O_RDONLY
          end
        end
      end

      describe '#writeonly' do
        describe 'with single call' do
          it 'sets the WRONLY bit' do
            expect(Flags.new.writeonly.to_i).to eq Platforms::Constants::O_WRONLY
          end
        end

        describe 'with multiple calls' do
          it 'sets the WRONLY bit' do
            expect(Flags.new.writeonly.writeonly.to_i).to eq Platforms::Constants::O_WRONLY
          end
        end

        describe 'where first call has true arg, second call has false arg' do
          it 'unsets the WRONLY bit' do
            expect(Flags.new.writeonly.writeonly(false).to_i).to eq Platforms::Constants::O_RDONLY
          end
        end
      end

      describe '#readwrite' do
        describe 'with single call' do
          it 'sets the WRONLY bit' do
            expect(Flags.new.readwrite.to_i).to eq Platforms::Constants::O_RDWR
          end
        end

        describe 'with multiple calls' do
          it 'sets the WRONLY bit' do
            expect(Flags.new.readwrite.readwrite.to_i).to eq Platforms::Constants::O_RDWR
          end
        end

        describe 'where first call has true arg, second call has false arg' do
          it 'unsets the WRONLY bit' do
            expect(Flags.new.readwrite.readwrite(false).to_i).to eq Platforms::Constants::O_RDONLY
          end
        end
      end

      describe 'chained mixed calls' do
        it 'ORs together the values' do
          bitwise_or = Platforms::Constants::O_RDWR | Platforms::Constants::O_APPEND | Platforms::Constants::O_CREAT |
          Platforms::Constants::O_TRUNC

          expect(
            Flags.new.
            readwrite.
            append.
            create.
            truncate.to_i
          ).to eq bitwise_or
        end
      end
    end
  end
end
