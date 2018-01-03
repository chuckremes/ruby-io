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
      layout \
        :bytes, [:uint8, Constants::FDSET_SIZE / 8]

      attr_accessor :max_fd

      def initialize(*args)
        super
        @max_fd = 0
      end

      def copy
        obj = FDSetStruct.new
        (Constants::FDSET_SIZE / 8).times do |i|
          obj[:bytes][i] = self[:bytes][i]
        end
        obj.max_fd = self.max_fd
        obj
      end

      def set?(fd:)
        byte_index, bit_index = indexes(fd: fd)
        byte = self[:bytes][byte_index]

        case bit_index
        when 0; (byte & Constants::FD_BIT0) > 0
        when 1; (byte & Constants::FD_BIT1) > 0
        when 2; (byte & Constants::FD_BIT2) > 0
        when 3; (byte & Constants::FD_BIT3) > 0
        when 4; (byte & Constants::FD_BIT4) > 0
        when 5; (byte & Constants::FD_BIT5) > 0
        when 6; (byte & Constants::FD_BIT6) > 0
        when 7; (byte & Constants::FD_BIT7) > 0
        end
      end

      def set(fd:)
        @max_fd = fd > @max_fd ? fd : @max_fd
        byte_index, bit_index = indexes(fd: fd)
        change(byte_index: byte_index, bit_index: bit_index, to_val: 1)
      end

      def clear(fd:)
        byte_index, bit_index = indexes(fd: fd)
        change(byte_index: byte_index, bit_index: bit_index, to_val: 0)
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

      def inspect
        string = "[\n"
        i = 0
        begin
          string += "  " + sprintf("%08b", self[:bytes][i]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 1]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 2]).reverse + ' | '
          string += "  " + sprintf("%08b", self[:bytes][i + 3]).reverse + "\n"
          i += 4
        end while i < (Constants::FDSET_SIZE / 8)
        string += "]\n"
        string
      end
    end

    class TimeSpecStruct < ::FFI::Struct
      layout \
        :tv_sec, :long,
        :tv_nsec, :long
    end

  end
end
