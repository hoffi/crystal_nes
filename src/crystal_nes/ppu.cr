require "./ppu/*"

module CrystalNes
  class Ppu
    include Registers
    include DebugHelpers

    getter front, memory

    def initialize(@mapper : CrystalNes::Mappers::Base,
                   @cpu : CrystalNes::Cpu)
      @memory = CrystalNes::Ppu::Memory.new(@mapper)
      @front = LibRay::RenderTexture2D.new()
      @back = Slice(LibRay::Color).new(256 * 240, LibRay::BLACK)

      @scanline = 0
      @cycle = 0
      @frame = 0

      @vram_addr = Loopy.new(0)
      @tram_addr = Loopy.new(0)
      @ppu_data_buffer = 0_u8
      @x_scroll = 0_u8

      @control = Control.new(0)
      @mask = Mask.new(0)
      @status = Status.new(0b10100000)

      @write_toggle = false
      @last_register_value = 0_u8
      @write_lock = false

      @bg_next_tile_id = 0_u8
      @bg_next_tile_attribute = 0_u8
      @bg_next_tile_lsb = 0_u8
      @bg_next_tile_msb = 0_u8

      @bg_shifter_pattern_lo = 0_u16
      @bg_shifter_pattern_hi = 0_u16
      @bg_shifter_attrib_lo = 0_u16
      @bg_shifter_attrib_hi = 0_u16
    end

    def init_front_buffer()
      @front = LibRay.load_render_texture(256, 240)
      LibRay.update_texture(@front.texture, @back)
    end

    def step()
      # "Odd Frame", skip cycle
      @cycle = 1 if @scanline == 0 && @cycle == 0

      # Start of new frame. Clear VBlank-Flag
      @status.vblank = 0 if @scanline == -1 && @cycle == 1

      if @scanline < 240 && (@mask.enable_background == 1 || @mask.enable_sprite == 1)
        if (@cycle >= 2 && @cycle < 257) || (@cycle >= 321 && @cycle < 338)
          update_shifters()

          case ((@cycle - 1) % 8)
          when 0 then
            load_background_shifters()
            fetch_nametable_byte()
          when 2 then fetch_attribute_byte()
          when 4 then fetch_tile_byte(:low)
          when 6 then fetch_tile_byte(:high)
          when 7 then increment_scroll_x()
          end
        end

        increment_scroll_y() if @cycle == 256

        if @cycle == 257
          load_background_shifters()
          copy_x()
        end

        fetch_nametable_byte() if @cycle == 338 || @cycle == 340

        copy_y() if @scanline == -1 && @cycle >= 280 && @cycle < 305
      end

      render() if @scanline >= 0 && @scanline < 240 && @cycle <= 256

      if @scanline == 241 && @cycle == 1
        LibRay.update_texture(@front.texture, @back)
        @status.vblank = 1
        @cpu.trigger_nmi() if @control.enable_nmi == 1
      end

      @cycle += 1
      if @cycle >= 341
        @cycle = 0
        @scanline += 1
        if @scanline >= 261
          @scanline = -1
        end
      end
    end

    private def fetch_nametable_byte()
      @bg_next_tile_id = @memory.read(0x2000 | (@vram_addr.value & 0x0FFF))
    end

    private def fetch_attribute_byte()
      @bg_next_tile_attribute =
        @memory.read(0x23C0_u16 | (
                     (@vram_addr.nametable_y.to_u16 << 11) |
                     (@vram_addr.nametable_x.to_u16 << 10) |
                     ((@vram_addr.coarse_y.to_u16 >> 2) << 3) |
                     (@vram_addr.coarse_x.to_u16 >> 2)))
      @bg_next_tile_attribute >>= 4 if (@vram_addr.coarse_y & 2) >= 1
      @bg_next_tile_attribute >>= 2 if (@vram_addr.coarse_x & 2) >= 1
      @bg_next_tile_attribute &= 3
    end

    private def fetch_tile_byte(mode)
      addr = (@control.pattern_background.to_u16 << 12) +
              (@bg_next_tile_id.to_u16 << 4) +
              @vram_addr.fine_y

      case mode
      when :low  then @bg_next_tile_lsb = @memory.read(addr)
      when :high then @bg_next_tile_msb = @memory.read(addr + 8_u16)
      end
    end

    private def render()
      x = (@cycle - 1)
      y = @scanline

      bg_pixel = 0_u16
      bg_palette = 0_u16

      if @mask.enable_background == 1
        bit_mux = 0x8000_u16 >> @x_scroll

        p0_pixel = (@bg_shifter_pattern_lo & bit_mux) > 0 ? 1 : 0
        p1_pixel = (@bg_shifter_pattern_hi & bit_mux) > 0 ? 1 : 0
        bg_pixel = (p1_pixel << 1) | p0_pixel

        bg_pal0 = (@bg_shifter_attrib_lo & bit_mux) > 0 ? 1 : 0
        bg_pal1 = (@bg_shifter_attrib_hi & bit_mux) > 0 ? 1 : 0
        bg_palette = (bg_pal1 << 1) | bg_pal0
      end

      bg_pixel = 0 if x < 8 && @mask.render_background_left == 0

      pal_idx = @memory.read(0x3F00 + (bg_palette << 2) + bg_pixel) &
        (@mask.grayscale > 0 ? 0x30 : 0x3F)
      @back[x + (y * 256)] = Palette.fetch(pal_idx)
    end

    private def load_background_shifters
      @bg_shifter_pattern_lo = (@bg_shifter_pattern_lo & 0xFF00) |
                               @bg_next_tile_lsb
      @bg_shifter_pattern_hi = (@bg_shifter_pattern_hi & 0xFF00) |
                               @bg_next_tile_msb

      @bg_shifter_attrib_lo = (@bg_shifter_attrib_lo & 0xFF00) |
                               ((@bg_next_tile_attribute & 1) > 0 ? 0xFF : 0x00)
      @bg_shifter_attrib_hi = (@bg_shifter_attrib_hi & 0xFF00) |
                               ((@bg_next_tile_attribute & 2) > 0 ? 0xFF : 0x00)
    end

    private def update_shifters
      return if @mask.enable_background == 0
      @bg_shifter_pattern_lo <<= 1
      @bg_shifter_pattern_hi <<= 1

      @bg_shifter_attrib_lo <<= 1
      @bg_shifter_attrib_hi <<= 1
    end

    private def increment_scroll_x
      return if @mask.enable_background == 0 && @mask.enable_sprite == 0
      if @vram_addr.coarse_x == 31
        @vram_addr.coarse_x = 0
        @vram_addr.nametable_x = ~@vram_addr.nametable_x
      else
        @vram_addr.coarse_x += 1
      end
    end

    private def increment_scroll_y
      return if @mask.enable_background == 0 && @mask.enable_sprite == 0
      if @vram_addr.fine_y < 7
        @vram_addr.fine_y += 1
      else
        @vram_addr.fine_y = 0

        if @vram_addr.coarse_y == 29
          @vram_addr.coarse_y = 0
          @vram_addr.nametable_y = ~@vram_addr.nametable_y
        elsif @vram_addr.coarse_y == 31
          @vram_addr.coarse_y = 0
        else
          @vram_addr.coarse_y += 1
        end
      end
    end

    private def copy_x
      return if @mask.enable_background == 0 && @mask.enable_sprite == 0
      @vram_addr.nametable_x = @tram_addr.nametable_x
      @vram_addr.coarse_x = @tram_addr.coarse_x
    end

    private def copy_y
      return if @mask.enable_background == 0 && @mask.enable_sprite == 0
      @vram_addr.fine_y = @tram_addr.fine_y
      @vram_addr.nametable_y = @tram_addr.nametable_y
      @vram_addr.coarse_y = @tram_addr.coarse_y
    end
  end
end
