require 'set'

class IO
  module Platforms
    #
    # Typedefs
    #
    typedef :long,   :uintptr_t
    typedef :long,   :intptr_t

    module Constants
      FDSET_SIZE      = 1024
      FD_BIT0         = 0x1
      FD_BIT1         = 1 << 1
      FD_BIT2         = 1 << 2
      FD_BIT3         = 1 << 3
      FD_BIT4         = 1 << 4
      FD_BIT5         = 1 << 5
      FD_BIT6         = 1 << 6
      FD_BIT7         = 1 << 7
    end

    #
    # BSD-specific functions
    #
    attach_function :select, [:int, :pointer, :pointer, :pointer, :pointer], :int, :blocking => true

    class FDSetStruct < ::FFI::Struct
      include Enumerable

      layout \
        :bytes, [:uint8, Constants::FDSET_SIZE / 8]

      attr_accessor :on

      def initialize(*args)
        super
        @on = SortedSet.new
      end

      def each
        @on.to_a.each { |fd| yield(fd) }
      end

      def copy_to(copy:)
        (Constants::FDSET_SIZE / 8).times do |i|
          copy[:bytes][i] = self[:bytes][i]
        end
        copy.on = self.on
        copy
      end

      def set?(fd:)
        byte_index, bit_index = indexes(fd: fd)
        byte = self[:bytes][byte_index]

        bitmatch = case bit_index
        when 0; (byte & Constants::FD_BIT0)
        when 1; (byte & Constants::FD_BIT1)
        when 2; (byte & Constants::FD_BIT2)
        when 3; (byte & Constants::FD_BIT3)
        when 4; (byte & Constants::FD_BIT4)
        when 5; (byte & Constants::FD_BIT5)
        when 6; (byte & Constants::FD_BIT6)
        when 7; (byte & Constants::FD_BIT7)
        end

        bitmatch > 0
      end

      def set(fd:)
        @on.add(fd)
        byte_index, bit_index = indexes(fd: fd)
        change(byte_index: byte_index, bit_index: bit_index, to_val: 1)
      end

      def clear(fd:)
        @on.delete(fd)
        byte_index, bit_index = indexes(fd: fd)
        change(byte_index: byte_index, bit_index: bit_index, to_val: 0)
      end

      def max_fd
        @on.max || -1
      end

      def inspect
        string = "[\n"
        i = 0
        begin
          string += "  " + sprintf("%08b", self[:bytes][i]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 1]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 2]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 3]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 4]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 5]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 6]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 7]).reverse + "\n"
          i += 8
        end while i < (Constants::FDSET_SIZE / 8)
        string += "]\n"
        string
      end

      private

      def change(byte_index:, bit_index:, to_val:)
        # for algorithm, see:  https://stackoverflow.com/questions/47981/how-do-you-set-clear-and-toggle-a-single-bit
        self[:bytes][byte_index] ^= (-to_val ^ self[:bytes][byte_index]) & (1 << bit_index);
      end

      def indexes(fd:)
        byte_index = fd / 8
        bit_index = (fd % 8)
        [byte_index, bit_index]
      end
    end

    class TimeSpecStruct < ::FFI::Struct
      layout \
        :tv_sec, :long,
        :tv_nsec, :long
    end

  end
end
