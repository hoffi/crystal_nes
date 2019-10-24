module CrystalNes
  module Mappers
    class Mapper0 < Base
      def initialize(cartridge : CrystalNes::Cartridge)
        @cartridge = cartridge
        @ram = IO::Memory.new(8 * 1024)
        @ram.write(Bytes.new(8 * 1024, 0_u8))
        @fallback_chr_ram = IO::Memory.new(8 * 1024)
        @fallback_chr_ram.write(Bytes.new(8 * 1024, 0_u8))
      end

      def read(address)
        if (0x0000..0x1FFF).includes?(address)
          if @cartridge.chr_rom_size == 0
            @fallback_chr_ram.pos = address
            @fallback_chr_ram.read_bytes(UInt8)
          else
            @cartridge.chr[address]
          end
        elsif (0x6000..0x7FFF).includes?(address)
          @ram.pos = address - 0x6000
          @ram.read_bytes(UInt8)
        elsif (0x8000..0xBFFF).includes?(address)
          @cartridge.prg[address - (0x8000 - 1)]
        elsif (0xC000..0xFFFF).includes?(address)
          if @cartridge.prg.size >= 0x8000
            @cartridge.prg[address - (0x8000 - 1)]
          else
            @cartridge.prg[address - (0xC000 - 1)]
          end
        else
          raise ArgumentError.new("WRONG ADDRESS: #{address}")
        end
      end

      def write(address, value)
        if (0x6000..0x7FFF).includes?(address)
          @ram.pos = address - 0x6000
          @ram.write_byte(value)
        elsif (0x0000..0x1FFF).includes?(address)
          #@cartridge.chr[address - (0x8000 - 1)] = value
          if @cartridge.chr_rom_size == 0
            @fallback_chr_ram.pos = address
            @fallback_chr_ram.write_byte(value)
          end
        elsif (0x8000..0xBFFF).includes?(address)
          #@cartridge.prg[address - (0x8000 - 1)] = value
        elsif (0xC000..0xFFFF).includes?(address)
          #if @cartridge.prg.size < 0xC000
          #  @cartridge.prg[address - (0xC000 - 1)] = value
          #else
          #  @cartridge.prg[address - (0x8000 - 1)] = value
          #end
        else
          raise ArgumentError.new("WRONG ADDRESS: #{address}")
        end
      end
    end
  end
end
