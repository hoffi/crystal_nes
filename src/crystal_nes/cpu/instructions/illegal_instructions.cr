module CrystalNes
  class Cpu
    module IllegalInstructions
      def slo(value)
        asl(value)
        ora(@bus.read(value))
        @cycles -= 1
      end

      def rla(value)
        rol(value)
        and(@bus.read(value))
        @cycles -= 1
      end

      def sre(value)
        lsr(value)
        eor(@bus.read(value))
        @cycles += 1
      end

      def rra(value)
        ror(value)
        adc(@bus.read(value))
        @cycles -= 1
      end

      def sax(address)
        @cycles += 3
        value = @a & @x
        @bus.write(address, value)
      end

      def lax(value)
        lda(value)
        ldx(value)
        @cycles -= 1
      end

      def dcp(value)
        dec(value)
        cmp(@bus.read(value))
        @cycles -= 2
      end

      def isc(value)
        inc(value)
        sbc(@bus.read(value))
        @cycles -= 2
      end
    end
  end
end
