require "./ppu/*"

module CrystalNes
  class Ppu < BusDevice
    include MainBusInterface

    MAX_HEIGHT = 256
    MAX_WIDTH = 240
    INTERNAL_SCREEN_SIZE = MAX_HEIGHT * MAX_WIDTH

    alias PixelBuffer = Slice(UInt32)

    getter nmi_triggered, bus
    setter swap_pixel_buffer_callback, nmi_triggered, oam_dma_handler, main_bus

    @swap_pixel_buffer_callback : PixelBuffer -> Void = ->(b : PixelBuffer) {}
    @oam_dma_handler : -> Void = ->() {}
    @main_bus : Bus

    def initialize(@mapper : Mapper)
      # The PPU has a custom bus.
      @bus = PpuBus.new(@mapper)
      @main_bus = uninitialized Bus

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
      @oam_address = 0_u8
      @oam = Bytes.new(256, 0_u8)

      # Sprites
      @sprite_count = 0
      @sprite_patterns = Slice(UInt32).new(8, 0_u32)
      @sprite_positions = Bytes.new(8, 0_u8)
      @sprite_priorities = Bytes.new(8, 0_u8)
      @sprite_indexes = Bytes.new(8, 0_u8)

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

    def power_up!
      @bus.power_up!
    end

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
          sprite_evaluation
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

      skip_left_bg = (x < 8 && @mask.background_left_column_enable == 0)
      skip_left_sprites = (x < 8 && @mask.sprite_left_column_enable == 0)

      background = skip_left_bg ? 0_u16 : background_pixel
      sprite_index, sprite = sprite_pixel
      sprite = 0_u16 if skip_left_sprites

      b = (background % 4) != 0
      s = (sprite % 4) != 0
      color =
        if !b && !s
          0x3F00_u16
        elsif !b && s
          sprite
        elsif b && !s
          background
        else
          if @sprite_indexes[sprite_index] == 0 && x < 255
            @status.sprite_zero_hit = 1
          end

          if @sprite_priorities[sprite_index] == 0
            sprite
          else
            background
          end
        end

      pal = @bus.read(color) & (@mask.greyscale == 1 ? 0x30 : 0x3F)
      @pixel_buffer[x + (y * MAX_HEIGHT)] = @palette.fetch(pal)
    end

    private def background_pixel
      return 0_u16 if @mask.background_enable == 0

      bit_mux = 0x8000_u16 >> @x_scroll

      pixel0 = (@bg_tile_shifter_lo & bit_mux) > 0 ? 1 : 0
      pixel1 = (@bg_tile_shifter_hi & bit_mux) > 0 ? 1 : 0
      bg_pixel = (pixel1 << 1) | pixel0

      palette0 = (@bg_attribute_shifter_lo & bit_mux) > 0 ? 1 : 0
      palette1 = (@bg_attribute_shifter_hi & bit_mux) > 0 ? 1 : 0
      bg_palette = (palette1 << 1) | palette0

      0x3F00_u16 | (bg_palette << 2) | bg_pixel
    end

    private def sprite_pixel
      return [0_u8, 0_u16] if @mask.sprite_enable == 0

      @sprite_count.times do |i|
        offset = (@cycle - 1) - @sprite_positions[i]
        next if offset < 0 || offset > 7
        offset = 7 - offset
        color = ((@sprite_patterns[i] >> (offset * 4)) & 0x0000000F)
        next if (color % 4) == 0
        return [i, 0x3F00_u16 | ((color | 0x10) % 64)]
      end

      [0_u8, 0_u16]
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

    private def sprite_evaluation
      height = @control.sprite_height == 0 ? 8 : 16
      @sprite_count = 0

      64.times do |i|
        y = @oam[i*4+0]
        tile = @oam[i*4+1]
        attr = @oam[i*4+2]
        x = @oam[i*4+3]
        row = @scanline - y
        next if row < 0 || row >= height
        if @sprite_count < 8
          @sprite_patterns[@sprite_count] =
            fetch_sprite_pattern(tile, attr, row, height)
          @sprite_positions[@sprite_count] = x
          @sprite_priorities[@sprite_count] = attr.bit(5)
          @sprite_indexes[@sprite_count] = i.to_u8
        end
        @sprite_count += 1
      end

      if @sprite_count > 8
        @sprite_count = 8
        @status.sprite_overflow = 1
      else
        @status.sprite_overflow = 0
      end
    end

    private def fetch_sprite_pattern(tile, attributes, row, sprite_height)
      address =
        if sprite_height == 8
          row = 7 - row if attributes.bit(7) == 1
          table = @control.sprite_tile
          (0x1000_u16 * table.to_u16) + (tile.to_u16 * 16) + row.to_u16
        else
          row = 15 - row if attributes.bit(7) == 1
          table = tile.bit(0)
          tile &= 0xFE
          if row > 7
            tile &+= 1
            row -= 8
          end
          (0x1000_u16 * table.to_u16) + (tile.to_u16 * 16) + row.to_u16
        end

      a = attributes.bits(0..1) << 2
      low_tile = @bus.read(address)
      high_tile = @bus.read(address + 8)
      data = 0_u32
      8.times do |i|
        pixel0 = pixel1 = 0_u8
        if attributes.bit(6) == 1
          pixel0 = low_tile.bit(0) << 0
          pixel1 = high_tile.bit(0) << 1
          low_tile >>= 1
          high_tile >>= 1
        else
          pixel0 = low_tile.bit(7) << 0
          pixel1 = high_tile.bit(7) << 1
          low_tile <<= 1
          high_tile <<= 1
        end

        data <<= 4
        data |= (a.to_u32 | pixel0.to_u32 | pixel1.to_u32)
      end
      data
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
