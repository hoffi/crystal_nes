module CrystalNes
  class Cpu
    module AddressingModes
      def load_immediate
        value = @bus.read(@pc)
        @pc += 1
        value
      end

      def load_zero_page
        value = @bus.read(@pc).to_u16
        @cycles += 1
        @pc += 1
        value
      end

      def load_zero_page_x
        # Important: First add the X register to the 8bit integer so it gets
        # wrapped properly. After this convert it to a 16bit integer.
        # For example: (0x80 + 0xFF) = 0x7F => 0x007F
        value = (@bus.read(@pc) &+ @x).to_u16
        @cycles += 1
        @pc += 1
        value
      end

      def load_zero_page_y
        # Important: First add the Y register to the 8bit integer so it gets
        # wrapped properly. After this convert it to a 16bit integer.
        # For example: (0x80 + 0xFF) = 0x7F => 0x007F
        value = (@bus.read(@pc) &+ @y).to_u16
        @cycles += 1
        @pc += 1
        value
      end

      def load_absolute
        value = read16(@pc)
        @cycles += 2
        @pc += 2
        value
      end

      def load_absolute_x(page_cross_cycles = true)
        value_1 = load_absolute
        value = value_1 &+ @x
        if page_cross_cycles && page_crossed?(value, value_1)
          @cycles += 1
          # Dummy-Read
          @bus.read(value &- 0x0100)
        end
        value
      end

      def load_absolute_y(page_cross_cycles = true)
        value_1 = load_absolute
        value = value_1 &+ @y
        @cycles += 1 if page_cross_cycles && page_crossed?(value, value_1)
        value
      end

      def load_indirect
        @cycles += 2
        addr = load_absolute
        result = read16(addr)
        result = addr + 1 if page_crossed?(addr, addr + 1)
        result
      end

      def load_indirect_x # or "Indexed Indirect"
        @cycles += 3
        read16_bug(load_zero_page_x)
      end

      def load_indirect_y(page_cross_cycles = true) # or "Indirect Indexed"
        value = read16(load_zero_page)
        real_value = value &+ @y
        if page_cross_cycles && page_crossed?(value, real_value)
          @cycles += 1
          # Dummy-Read
          @bus.read(value &- 0x0100)
        end
        @cycles += 2
        real_value
      end

      def load_relative
        value = @bus.read(@pc).to_u16
        @pc += 1
        @pc &+ ((value >= 0x80) ? (value &- 0x100) : value)
      end
    end
  end
end
