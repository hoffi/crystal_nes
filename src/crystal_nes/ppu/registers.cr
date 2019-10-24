module CrystalNes
  class Ppu
    module Registers
      struct Control < BitStruct(UInt8)
        bf enable_nmi : UInt8, 1
        bf slave_mode : UInt8, 1 # Unused
        bf sprite_height : UInt8, 1
        bf pattern_background : UInt8, 1
        bf pattern_sprite : UInt8, 1
        bf increment_mode : UInt8, 1
        bf nametable_y : UInt8, 1
        bf nametable_x : UInt8, 1
      end

      struct Mask < BitStruct(UInt8)
        bf emphasise_blue : UInt8, 1
        bf emphasise_green : UInt8, 1
        bf emphasise_red : UInt8, 1
        bf enable_sprite : UInt8, 1
        bf enable_background : UInt8, 1
        bf render_sprite_left : UInt8, 1
        bf render_background_left : UInt8, 1
        bf grayscale : UInt8, 1
      end

      struct Status < BitStruct(UInt8)
        bf vblank : UInt8, 1
        bf sprite_zero_hit : UInt8, 1
        bf sprite_overflow : UInt8, 1
        bf unused : UInt8, 5
      end

      struct Loopy < BitStruct(UInt16)
        bf unused : UInt8, 1
        bf fine_y : UInt8, 3
        bf nametable_y : UInt8, 1
        bf nametable_x : UInt8, 1
        bf coarse_y : UInt8, 5
        bf coarse_x : UInt8, 5
      end

      def read(address)
        read_data =
          case address
          when 0x2002 then
            data = (@status.value & 0xE0) | (@ppu_data_buffer & 0x1F)
            @status.vblank = 0
            @write_toggle = false
            data
          when 0x2007 then
            address = @vram_addr.value
            data = @ppu_data_buffer.dup

            @ppu_data_buffer = @memory.read(address)
            @vram_addr.value = address &+ (@control.increment_mode == 1 ? 32 : 1)

            if address >= 0x3F00
              @ppu_data_buffer & (@mask.grayscale > 0 ? 0x30 : 0x3F)
            else
              data
            end
          else false
          end

        if read_data == false
          @last_register_value
        else
          @last_register_value = read_data.as(UInt8)
        end
      end

      def write(address, data)
        case address
        when 0x2000 then # Control
          return 0_u8 if @write_lock
          if @status.vblank == 1 && @control.enable_nmi == 0 && data.bit(7) == 1
            @cpu.trigger_nmi()
          end
          @control.value = data
          @tram_addr.nametable_x = @control.nametable_x
          @tram_addr.nametable_y = @control.nametable_y
        when 0x2001 then
          return 0_u8 if @write_lock
          @mask.value = data # Mask
        when 0x2005 then # Scroll
          return 0_u8 if @write_lock
          unless @write_toggle
            @x_scroll = data & 7
            @tram_addr.coarse_x = data >> 3
            @write_toggle = true
          else
            @tram_addr.fine_y = data & 7
            @tram_addr.coarse_y = data >> 3
            @write_toggle = false
          end
        when 0x2006 then # PPU Address
          return 0_u8 if @write_lock
          unless @write_toggle
            @tram_addr.value =
              ((data & 0x3F).to_u16 << 8) | (@tram_addr.value & 0x00FF)
            @write_toggle = true
          else
            @tram_addr.value = (@tram_addr.value & 0xFF00) | data
            @vram_addr.value = @tram_addr.value
            @write_toggle = false
          end
        when 0x2007 then # PPU Data
          address = @vram_addr.value
          @memory.write(address, data)
          @vram_addr.value = address &+ (@control.increment_mode == 1 ? 32 : 1)
        end
        @last_register_value = data
      end
    end
  end
end
