module CrystalNes
  class INes
    INES_FILEHEADER = ['N', 'E', 'S', '\u001A'].map(&.ord)

    def initialize(filename : String)
      @filename = filename
    end

    def parse
      data = File.read(@filename).to_slice
      if data[0, 4].to_a != INES_FILEHEADER
        raise ArgumentError.new("Wrong file type!")
      end

      # Flags 6
      non_volatile_memory = data[6] & 2
      trainer_present = data[6] & 4
      trainer_size = trainer_present == 1 ? 512 : 0
      puts "Battery: #{non_volatile_memory == 0 ? "NO" : "YES"}"
      puts "Trainer: #{trainer_present == 0 ? "NO" : "YES"}"

      mirror1 = data[6] & 1
      mirror2 = (data[6] >> 3) & 1
      mirror = mirror1 | (mirror2 << 1)

      # Flags 7
      console_type = data[7] & 3
      case console_type
      when 0 then puts "Console-Type: Nintendo Entertainment System"
      when 1 then puts "Console-Type: Nintento Vs. System"
      when 2 then puts "Console-Type: Nintendo Playchoice 10"
      when 3 then puts "Console-Type: Extended Console Type"
      end
      nes2_format_identifier = data[7] & 12
      puts "NES2.0-Format: #{nes2_format_identifier}"

      # Flags 9
      tv_system = data[9] & 1 # 0 = NTSC, 1 = PAL
      puts "TV-System: #{tv_system == 0 ? "NTSC" : "PAL"}"

      # Mapper Number
      mapper_number_lo = (data[6] & 0xF0) >> 4
      mapper_number_hi = (data[7] & 0xF0) >> 4
      mapper_number = ((mapper_number_hi) << 4) | mapper_number_lo

      # PRG and CHR Data
      prg_rom_size = data[4]
      prg_ram_size = data[8]
      prg_size = (16384 * prg_rom_size)
      prg = data[trainer_size + 15, prg_size]

      chr_rom_size = data[5]
      chr = data[trainer_size + prg_size + 16, (8192 * chr_rom_size)]

      CrystalNes::Cartridge.new(
        prg_rom_size,
        chr_rom_size,
        mapper_number,
        mirror,
        prg,
        chr,
        prg_ram_size
      )
    end
  end
end
