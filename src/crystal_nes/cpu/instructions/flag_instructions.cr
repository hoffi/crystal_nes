module CrystalNes
  class Cpu
    module FlagInstructions
      def cmp(value)
        result = @a &- value
        @p.carry = @a >= value
        @p.zero = @a == value
        @p.negative = result.bit(7) == 1
        @cycles += 2
      end

      def cpx(value)
        result = @x &- value
        @p.carry = @x >= value
        @p.zero = @x == value
        @p.negative = result.bit(7) == 1
        @cycles += 2
      end

      def cpy(value)
        result = @y &- value
        @p.carry = @y >= value
        @p.zero = @y == value
        @p.negative = result.bit(7) == 1
        @cycles += 2
      end

      def bit(value)
        @cycles += 2
        result = @a & value
        @p.zero = result == 0
        @p.overflow = value.bit(6) == 1
        @p.negative = value.bit(7) == 1
      end

      def php
        push(@p.to_u8)
        @cycles += 3
      end

      def plp
        @p.from_value(pop8)
        @p.unused = true # Unused-Flag is always true!
        @cycles += 4
      end

      def sei
        @p.interupt_disable = true
        @cycles += 2
      end

      def sed
        @p.decimal = true
        @cycles += 2
      end

      def sec
        @p.carry = true
        @cycles += 2
      end

      def cli
        @p.interupt_disable = false
        @cycles += 2
      end

      def cld
        @p.decimal = false
        @cycles += 2
      end

      def clc
        @p.carry = false
        @cycles += 2
      end

      def clv
        @p.overflow = false
        @cycles += 2
      end
    end
  end
end
