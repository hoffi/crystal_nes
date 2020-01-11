module CrystalNes
  class Ppu < BusDevice
    class PpuBus
      setter mirror_mode

      def initialize(@mapper : Mapper)
        @mirror_mode = MirrorMode::Horizontal
        @nametable = Bytes.new(2048, 0_u8)
        @palette_indices = Bytes.new(32, 0x3F_u8)
      end

      MIRRORING_LOOKUP_TABLE = {
        MirrorMode::Horizontal => {0, 0, 1, 1},
        MirrorMode::Vertical => {0, 1, 0, 1},
        MirrorMode::Single0 => {0, 0, 0, 0},
        MirrorMode::Single1 => {1, 1, 1, 1}
      }

      def read(address, debug = false)
        address &= 0x3FFF
        if address >= 0 && address < 0x2000
          # Pattern Tables
          @mapper.read(address, debug)
        elsif address >= 0x2000 && address < 0x3F00
          # Nametables
          address &= 0x0FFF
          table = (address // 0x0400)
          offset = address & 0x03FF
          base_addr = MIRRORING_LOOKUP_TABLE[@mirror_mode][table] * 1024
          @nametable[base_addr + offset]
        elsif address >= 0x3F00 && address <= 0x3FFF
          # Palette Indices
          addr = address & 0x001F
          addr = 0 if addr % 4 == 0
          @palette_indices[addr]
        else
          raise "Unsupported PPU-Bus Address: #{address.to_s(16, true)}!"
        end
      end

      def write(address, data)
        address &= 0x3FFF
        if address >= 0 && address < 0x2000
          # Pattern Tables
          @mapper.write(address, data)
        elsif address >= 0x2000 && address < 0x3F00
          # Nametables
          address &= 0x0FFF
          table = (address // 0x0400)
          offset = address & 0x03FF
          base_addr = MIRRORING_LOOKUP_TABLE[@mirror_mode][table] * 1024
          @nametable[base_addr + offset] = data
        elsif address >= 0x3F00 && address <= 0x3FFF
          # Palette Indices
          addr = address & 0x001F
          addr = 0 if addr % 4 == 0
          @palette_indices[addr] = data
        else
          raise "Unsupported PPU-Bus Address: #{address.to_s(16, true)}!"
        end
      end
    end
  end
end
