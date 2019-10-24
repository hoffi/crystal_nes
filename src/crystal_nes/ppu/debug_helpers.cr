module CrystalNes
  class Ppu
    module DebugHelpers
      def get_palette_colors(palette)
        StaticArray(UInt32, 4).new do |i|
          Palette.fetch(@memory.read(0x3F00 + (palette << 2) + i) & 0x3F)
        end
      end

      def draw_pattern_table(table, palette, texture)
        texture_data = Slice(UInt32).new(128 * 128)
        16.times do |tile_y|
          16.times do |tile_x|
            # 2D -> 1D
            offset = (tile_y * 256_u16) + (tile_x * 16_u16)
            8.times do |row|
              tile_lsb = @memory.read((table * 0x1000).to_u16 + offset + row + 0)
              tile_msb = @memory.read((table * 0x1000).to_u16 + offset + row + 8)

              8.times do |col|
                pixel = ((tile_lsb & 1) << 1) | (tile_msb & 1)
                tile_lsb >>= 1
                tile_msb >>= 1
                pal_idx = @memory.read(0x3F00 + (palette << 2) + pixel) & 0x3F
                x = tile_x * 8 + (7 - col)
                y = tile_y * 8 + row
                texture_data[x + (y * 128)] = Palette.fetch(pal_idx)
              end
            end
          end
        end
        LibRay.update_texture(texture, texture_data)
      end
    end
  end
end
