module CrystalNes
  class Cpu
    class StatusRegister
      getter carry, zero, interupt_disable, decimal, break_flag, unused,
        overflow, negative
      setter carry, zero, interupt_disable, decimal, break_flag, unused,
        overflow, negative

      def initialize
        @carry = false
        @zero = false
        @interupt_disable = false
        @decimal = false
        @break_flag = false
        @unused = false
        @overflow = false
        @negative = false
      end

      def from_value(value : UInt8)
        @carry = value.bit(0) == 1
        @zero = value.bit(1) == 1
        @interupt_disable = value.bit(2) == 1
        @decimal = value.bit(3) == 1
        @break_flag = value.bit(4) == 1
        @unused = value.bit(5) == 1
        @overflow = value.bit(6) == 1
        @negative = value.bit(7) == 1
      end

      def to_u8 : UInt8
        to_i(@carry) << 0 |
          to_i(@zero) << 1 |
          to_i(@interupt_disable) << 2 |
          to_i(@decimal) << 3 |
          to_i(@break_flag) << 4 |
          to_i(@unused) << 5 |
          to_i(@overflow) << 6 |
          to_i(@negative) << 7
      end

      private def to_i(flag : Bool)
        flag ? 1_u8 : 0_u8
      end
    end
  end
end
