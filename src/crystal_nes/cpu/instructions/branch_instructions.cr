module CrystalNes
  class Cpu
    module BranchInstructions
      def nop
        @cycles += 2
      end

      def nop(_unused)
        @cycles += 2
      end

      def jsr(address)
        push(@pc - 1)
        @pc = address
        @cycles += 4
      end

      def jmp(address)
        @pc = address
        @cycles += 1
      end

      def rts
        @bus.read(@pc) # Dummy-Read
        @pc = pop16 + 1
        @cycles += 6
      end

      def rti
        @bus.read(@pc) # Dummy-Read
        @p.from_value(pop8)
        @pc = pop16
        @cycles += 6
      end

      def bpl(address)
        unless @p.negative
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def bmi(address)
        if @p.negative
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def beq(address)
        if @p.zero
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def bne(address)
        unless @p.zero
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def bcs(address)
        if @p.carry
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def bcc(address)
        unless @p.carry
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def bvc(address)
        unless @p.overflow
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end

      def bvs(address)
        if @p.overflow
          @cycles += 1 if page_crossed?(@pc, address)
          @pc = address
          @cycles += 1
        end
        @cycles += 2
      end
    end
  end
end
