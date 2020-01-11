module CrystalNes
  class Cpu
    module MoveInstructions
      def sta(address)
        @bus.write(address, @a)
        @cycles += 2
      end

      def stx(address)
        @bus.write(address, @x)
        @cycles += 2
      end

      def sty(address)
        @bus.write(address, @y)
        @cycles += 2
      end

      def ldy(value)
        @y = value
        @p.zero = value == 0
        @p.negative = value.bit(7) == 1
        @cycles += 2
      end

      def ldx(value)
        @x = value
        @p.zero = value == 0
        @p.negative = value.bit(7) == 1
        @cycles += 2
      end

      def lda(value)
        @a = value
        @p.zero = value == 0
        @p.negative = value.bit(7) == 1
        @cycles += 2
      end

      def tay
        @y = @a
        @cycles += 2
        @p.zero = @y == 0
        @p.negative = @y.bit(7) == 1
      end

      def tya
        @a = @y
        @cycles += 2
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def txa
        @a = @x
        @cycles += 2
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
      end

      def tax
        @x = @a
        @cycles += 2
        @p.zero = @x == 0
        @p.negative = @x.bit(7) == 1
      end

      def tsx
        @x = @sp
        @cycles += 2
        @p.zero = @x == 0
        @p.negative = @x.bit(7) == 1
      end

      def txs
        @sp = @x
        @cycles += 2
      end

      def pha
        push(@a)
        @cycles += 3
      end

      def pla
        @a = pop8
        @p.zero = @a == 0
        @p.negative = @a.bit(7) == 1
        @cycles += 4
      end
    end
  end
end
