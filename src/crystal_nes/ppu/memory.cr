module CrystalNes
  class Ppu
    class Memory
      getter name_table, palette_data
      def initialize(@mapper : CrystalNes::Mappers::Base)
        @name_table = [Bytes.new(1024), Bytes.new(1024)]
        @palette_data = Bytes.new(32, 0x0f_u8)
      end

      MirrorLookup = [
        {0, 0, 1, 1}, # Horizontal
        {0, 1, 0, 1}, # Vertical
        {0, 1, 2, 3}, # Four
        {0, 0, 0, 0}, # Single0
        {1, 1, 1, 1}, # Single1
      ]

      def read(address)
        address &= 0x3FFF
        if (0x0000..0x1FFF).includes?(address)
          @mapper.read(address)
        elsif (0x2000..0x3EFF).includes?(address)
          address &= 0x0FFF
          table = (address // 0x0400)
          offset = address & 0x03FF
          @name_table[MirrorLookup[@mapper.mirror_mode][table]][offset]
        elsif (0x3F00..0x3FFF).includes?(address)
          addr = address & 0x001F
          addr = 0 if addr % 4 == 0
          @palette_data[addr]
        else
          raise ArgumentError.new("WRONG PPU ADDRESS: #{Utils.hex(address.to_u16)}")
        end
      end

      def write(address, value)
        address &= 0x3FFF
        if (0x0000..0x1FFF).includes?(address)
          @mapper.write(address, value)
        elsif (0x2000..0x3EFF).includes?(address)
          address &= 0x0FFF
          table = (address // 0x0400)
          offset = address & 0x03FF
          @name_table[MirrorLookup[@mapper.mirror_mode][table]][offset] = value
        elsif (0x3F00..0x3FFF).includes?(address)
          addr = address & 0x001F
          addr = 0 if addr % 4 == 0
          #puts "#{addr}: #{Utils.hex(value)}"
          @palette_data[addr] = value
        else
          raise ArgumentError.new("WRONG PPU ADDRESS: #{address}")
        end
      end
    end
  end
end
