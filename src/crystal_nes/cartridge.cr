module CrystalNes
  struct Cartridge
    property prg_rom_size : UInt8
    property chr_rom_size : UInt8
    property mapper_number : UInt8
    property mirror : UInt8
    property prg_ram_size : UInt8

    property prg : Bytes
    property chr : Bytes

    def initialize(@prg_rom_size, @chr_rom_size, @mapper_number, @mirror, @prg,
                   @chr, @prg_ram_size)
    end

    def infos
      {
        prg_rom_size: @prg_rom_size,
        chr_rom_size: @chr_rom_size,
        mapper: @mapper_number,
        mirror_mode: @mirror,
        prg_ram_size: @prg_ram_size
      }
    end
  end
end
