# http://wiki.nesdev.com/w/index.php/NROM
module CrystalNes
  module MapperBackend
    class Nrom < Base
      @fallback_chr_ram : Bytes?
      @more_than_16kb : Bool
      @has_chr_data : Bool
      @prg_rom : Bytes
      @chr_rom : Bytes

      def initialize(rom_data)
        @prg_rom = rom_data.prg_rom
        @chr_rom = rom_data.chr_rom

        # PRG Ram Size of 0 mean 8 KB; for compatibility
        @ram = Bytes.new([1, rom_data.prg_ram_size.to_i].max * 8192, 0_u8)

        @has_chr_data = rom_data.chr_rom_size > 0
        @more_than_16kb = rom_data.prg_rom_size > 1

        # If the ROM has no CHR-Data the CHR-Memory-Space is working as a RAM.
        @fallback_chr_ram = Bytes.new(8192, 0_u8) unless @has_chr_data
      end

      def read(address, _debug = false)
        if address >= 0 && address < 0x2000
          if @has_chr_data
            @chr_rom[address]
          else
            @fallback_chr_ram.as(Bytes)[address]
          end
        elsif address >= 0x6000 && address < 0x8000
          @ram[address - 0x5FFF]
        elsif address >= 0x8000 && address < 0xC000
          @prg_rom[address - 0x7FFF]
        elsif address >= 0xC000 && address <= 0xFFFF
          if @more_than_16kb
            @prg_rom[address - 0x7FFF]
          else
            # If PRG is less than 16 KB the content is mirrored
            @prg_rom[address - 0xBFFF]
          end
        else
          raise "Unsupported Mapper Address: #{address.to_s(16, true)}!"
        end
      end

      def write(address, data)
        if address >= 0 && address < 0x2000 && !@has_chr_data
          @fallback_chr_ram.as(Bytes)[address] = data
        elsif address >= 0x6000 && address < 0x8000
          @ram[address - 0x5FFF] = data
        else
          raise "Unsupported Mapper Address: #{address.to_s(16, true)}!"
        end
      end
    end
  end
end
