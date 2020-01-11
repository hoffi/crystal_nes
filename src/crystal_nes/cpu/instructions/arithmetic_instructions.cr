module CrystalNes
  class Cpu
    module ArithmeticInstructions
      def inc(address)
        value = @bus.read(address) &+ 1
        @bus.write(address, value)
        @p.zero = value == 0
        @p.negative = value.bit(7) == 1
        @cycles += 5
      end

      def inx
        @x &+= 1
        @p.zero = @x == 0
        @p.negative = @x.bit(7) == 1
        @cycles += 2
      end

      def iny
        @y &+= 1
        @p.zero = @y == 0
        @p.negative = @y.bit(7) == 1
        @cycles += 2
      end

      def dec(address)
        value = @bus.read(address) &- 1
        @bus.write(address, value)
        @p.zero = value == 0
        @p.negative = value.bit(7) == 1
        @cycles += 5
      end

      def dex
        @x &-= 1
        @p.zero = @x == 0
        @p.negative = @x.bit(7) == 1
        @cycles += 2
      end

      def dey
        @y &-= 1
        @p.zero = @y == 0
        @p.negative = @y.bit(7) == 1
        @cycles += 2
      end

      def lsr # LSR for Accumulator
        @cycles += 2
        @p.carry = @a.bit(0) == 1
        @a >>= 1
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def lsr(address)
        @cycles += 2
        value = @bus.read(address)
        @p.carry = value.bit(0) == 1
        value >>= 1
        @bus.write(address, value)
        @p.zero = value == 0
        @p.negative = value.bit(7) == 1
      end

      def asl # ASL for Accumulator
        @cycles += 2
        @p.carry = @a.bit(7) == 1
        @a <<= 1
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def asl(address)
        @cycles += 4
        data = @bus.read(address)
        @p.carry = data.bit(7) == 1
        data <<= 1
        @bus.write(address, data)
        @p.zero = data == 0
        @p.negative = data.bit(7) == 1
      end

      def ror # ROR for Accumulator
        @cycles += 2
        carry = @p.carry ? 1_u8 : 0_u8
        @p.carry = @a.bit(0) == 1
        @a = (@a >> 1) | (carry << 7)
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def ror(address)
        @cycles += 4
        carry = @p.carry ? 1_u8 : 0_u8
        data = @bus.read(address)
        @p.carry = data.bit(0) == 1
        data = (data >> 1) | (carry << 7)
        @bus.write(address, data)
        @p.zero = data == 0
        @p.negative = data.bit(7) == 1
      end

      def rol # ROL for Accumulator
        @cycles += 2
        carry = @p.carry ? 1_u8 : 0_u8
        @p.carry = @a.bit(7) == 1
        @a = (@a << 1) | carry
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def rol(address)
        @cycles += 4
        carry = @p.carry ? 1_u8 : 0_u8
        data = @bus.read(address)
        @p.carry = data.bit(7) == 1
        data = (data << 1) | carry
        @bus.write(address, data)
        @p.zero = data == 0
        @p.negative = data.bit(7) == 1
      end

      def and(value)
        @cycles += 2
        @a &= value
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def ora(value)
        @cycles += 2
        @a |= value
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def eor(value)
        @cycles += 2
        @a ^= value
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def adc(value)
        @cycles += 2
        carry = @p.carry ? 1 : 0
        result = @a &+ value &+ carry

        @p.carry = ((@a.to_u16 &+ value &+ carry) & 0xFF00) > 0
        @p.zero = result == 0
        @p.negative = result.bit(7) == 1
        @p.overflow = ((@a ^ result) & (value ^ result) & 0x80) > 0
        @a = result
      end

      def sbc(value)
        @cycles += 2
        carry = @p.carry ? 0 : 1
        result = @a &- value &- carry

        @p.carry = ((@a.to_u16 &- value &- carry) & 0xFF00) == 0
        @p.zero = result == 0
        @p.negative = result.bit(7) == 1
        @p.overflow = ((@a ^ value) & (@a ^ result) & 0x80) > 0
        @a = result
      end
    end
  end
end
