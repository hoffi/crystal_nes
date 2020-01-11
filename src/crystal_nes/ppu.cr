require "./ppu/*"

module CrystalNes
  class Ppu < BusDevice
    include MainBusInterface

    MAX_HEIGHT = 256
    MAX_WIDTH = 240
    INTERNAL_SCREEN_SIZE = MAX_HEIGHT * MAX_WIDTH

    alias PixelBuffer = Slice(UInt32)

    getter nmi_triggered, bus
    setter swap_pixel_buffer_callback, nmi_triggered

    @swap_pixel_buffer_callback : PixelBuffer -> Void = ->(b : PixelBuffer) {}

    def initialize(@mapper : Mapper)
      # The PPU has a custom bus.
      @bus = PpuBus.new(@mapper)

      @palette = Palette.new
      @pixel_buffer = PixelBuffer.new(INTERNAL_SCREEN_SIZE, 0_u32)

      # Registers
      # See http://wiki.nesdev.com/w/index.php/PPU_power_up_state for initial
      # values.
      @control = Ppu::ControlRegister.new(Bytes[0])
      @mask = Ppu::MaskRegister.new(Bytes[0])
      @status = Ppu::StatusRegister.new(Bytes[0xA0])
      @v = Ppu::LoopyRegister.new(Bytes[0, 0])
      @t = Ppu::LoopyRegister.new(Bytes[0, 0])
      @x_scroll = 0_u8

      @nmi_delay = 0_u8

      @write_toggle = false
      @ppu_data_buffer = 0_u8
      @register_latch = 0_u8

      @nmi_triggered = false
      @frame_toggle = false
      @cycle = 0
      @scanline = 0

      @bg_nametable_byte = 0_u8
      @bg_attribute_table_byte = 0_u8
      @bg_tile_lo = 0_u8
      @bg_tile_hi = 0_u8
      @bg_tile_shifter_lo = 0_u16
      @bg_tile_shifter_hi = 0_u16
      @bg_attribute_shifter_lo = 0_u16
      @bg_attribute_shifter_hi = 0_u16
    end

    def set_mirror_mode(mode : MirrorMode); @bus.mirror_mode = mode; end

    def step
      # "Odd Frame", skip cycle
      return @cycle = 1 if @frame_toggle && @scanline == 0 && @cycle == 0

      if @nmi_delay > 0
        @nmi_delay -= 1
        if @nmi_delay == 0
          @nmi_triggered = true
        end
      end

      # Start of new frame. Clear the status register flags.
      if @scanline == 261 && @cycle == 1
        @status.vblank = 0
        @status.sprite_zero_hit = 0
        @status.sprite_overflow = 0
      end

      copy_y if @scanline == 261 && @cycle >= 280 && @cycle < 305

      if (@scanline < 240 || @scanline == 261) &&
         (@mask.background_enable == 1 || @mask.sprite_enable == 1)
        if (@cycle >= 2 && @cycle < 257) || (@cycle >= 321 && @cycle < 338)
          update_shifters

          case (@cycle - 1) % 8
          when 0 then load_bg_shifters; fetch_nametable_byte
          when 2 then fetch_attribute_table_byte
          when 4 then fetch_tile_byte :low
          when 6 then fetch_tile_byte :high
          when 7 then increment_scroll_x
          end
        end

        increment_scroll_y if @cycle == 256

        if @cycle == 257
          load_bg_shifters
          copy_x
        end

        fetch_nametable_byte if @cycle == 338 || @cycle == 340

        render_pixel if @scanline < 240 && @cycle <= 256
      end

      if @scanline == 241 && @cycle == 1
        @swap_pixel_buffer_callback.call(@pixel_buffer)
        @status.vblank = 1
        # TODO: This should not be necessary.
        # This delay seems to fix the timing of the NMI.
        # @nmi_triggered = true if @control.nmi_enable == 1
        @nmi_delay = 880 if @control.nmi_enable == 1
      end

      @cycle += 1
      if @cycle == 341
        @cycle = 0
        @scanline += 1
        if @scanline == 262
          @scanline = 0
          @frame_toggle = !@frame_toggle
        end
      end
    end

    def render_pixel
      x = @cycle - 1
      y = @scanline

      bg_pixel = 0_u8
      bg_palette = 0_u8

      skip_left_bg = (x < 8 && @mask.background_left_column_enable == 0)
      if @mask.background_enable == 1 && !skip_left_bg
        bit_mux = 0x8000_u16 >> @x_scroll

        pixel0 = (@bg_tile_shifter_lo & bit_mux) > 0 ? 1 : 0
        pixel1 = (@bg_tile_shifter_hi & bit_mux) > 0 ? 1 : 0
        bg_pixel = (pixel1 << 1) | pixel0

        palette0 = (@bg_attribute_shifter_lo & bit_mux) > 0 ? 1 : 0
        palette1 = (@bg_attribute_shifter_hi & bit_mux) > 0 ? 1 : 0
        bg_palette = (palette1 << 1) | palette0
      end

      pal_idx = @bus.read(0x3F00_u16 | (bg_palette << 2) | bg_pixel) &
        (@mask.greyscale == 1 ? 0x30 : 0x3F)
      @pixel_buffer[x + (y * MAX_HEIGHT)] = @palette.fetch(pal_idx)
    end

    private def fetch_nametable_byte
      @bg_nametable_byte = @bus.read(0x2000_u16 | (@v.to_u16 & 0x0FFF))
    end

    private def fetch_attribute_table_byte
      @bg_attribute_table_byte =
        @bus.read(
          0x23C0_u16 |
            (@v.nametable_y.to_u16 << 11) |
            (@v.nametable_x.to_u16 << 10) |
            ((@v.coarse_y >> 2) << 3) |
            (@v.coarse_x >> 2)
        )

      @bg_attribute_table_byte >>= 4 if (@v.coarse_y & 2) >= 1
      @bg_attribute_table_byte >>= 2 if (@v.coarse_x & 2) >= 1
      @bg_attribute_table_byte &= 3
    end

    private def fetch_tile_byte(mode)
      addr = (@control.background_tile.to_u16 << 12) |
        (@bg_nametable_byte.to_u16 << 4) |
        @v.fine_y

      case mode
      when :low  then @bg_tile_lo = @bus.read(addr)
      when :high then @bg_tile_hi = @bus.read(addr + 8_u16)
      end
    end

    private def update_shifters
      if @mask.background_enable == 1
        @bg_tile_shifter_lo <<= 1
        @bg_tile_shifter_hi <<= 1
        @bg_attribute_shifter_lo <<= 1
        @bg_attribute_shifter_hi <<= 1
      end
    end

    private def load_bg_shifters
      @bg_tile_shifter_lo = (@bg_tile_shifter_lo & 0xFF00) | @bg_tile_lo
      @bg_tile_shifter_hi = (@bg_tile_shifter_hi & 0xFF00) | @bg_tile_hi

      @bg_attribute_shifter_lo = (@bg_attribute_shifter_lo & 0xFF00) |
                                 ((@bg_attribute_table_byte & 0b01) > 0 ? 0xFF_u16 : 0_u16)
      @bg_attribute_shifter_hi = (@bg_attribute_shifter_hi & 0xFF00) |
                                 ((@bg_attribute_table_byte & 0b10) > 0 ? 0xFF_u16 : 0_u16)
    end

    private def increment_scroll_x
      return if @mask.background_enable == 0 && @mask.sprite_enable == 0
      if @v.coarse_x == 31
        @v.coarse_x = 0
        @v.nametable_x = ~@v.nametable_x
      else
        @v.coarse_x += 1
      end
    end

    private def increment_scroll_y
      return if @mask.background_enable == 0 && @mask.sprite_enable == 0
      if @v.fine_y < 7
        @v.fine_y += 1
      else
        @v.fine_y = 0

        if @v.coarse_y == 29
          @v.coarse_y = 0
          @v.nametable_y = ~@v.nametable_y
        elsif @v.coarse_y == 31
          @v.coarse_y = 0
        else
          @v.coarse_y += 1
        end
      end
    end

    private def copy_x
      return if @mask.background_enable == 0 && @mask.sprite_enable == 0
      @v.nametable_x = @t.nametable_x
      @v.coarse_x = @t.coarse_x
    end

    private def copy_y
      return if @mask.background_enable == 0 && @mask.sprite_enable == 0
      @v.fine_y = @t.fine_y
      @v.nametable_y = @t.nametable_y
      @v.coarse_y = @t.coarse_y
    end
  end
end
