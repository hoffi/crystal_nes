require "bindata"

module CrystalNes
  module FileFormats
    class Nes < BinData
      IDENTIFIER = "NES\u001A"
      endian little

      string :identifier, default: IDENTIFIER, length: ->{ IDENTIFIER.size }

      uint8 :prg_rom_size
      uint8 :chr_rom_size

      bit_field do # Flags 6
        bits 4, :mapper_number_lo
        bool :ignore_mirror_mode, default: false
        bool :contains_trainer, default: false
        bool :contains_battery, default: false
        enum_bits 1, mirror_mode : MirrorMode = MirrorMode::Horizontal
      end

      bit_field do # Flags 7
        bits 4, :mapper_number_hi
        bits 4, :reserved
      end

      uint8 :prg_ram_size # Flags 8

      bit_field do # Flags 9
        bits 7, :reserved
        enum_bits 1, tv_system : TvSystem = TvSystem::NTSC
      end

      uint8 :flags_10 # Flags 10, TODO

      bytes :_padding, length: ->{ 4 }

      bytes :trainer_data, length: ->{ 512 }, onlyif: ->{ contains_trainer }
      bytes :prg_rom, length: ->{ prg_rom_size.to_i * 16 * 1024 }

      uint8 :_padding2

      bytes :chr_rom, length: ->{ chr_rom_size.to_i * 8 * 1024 }

      def mapper_number
        (mapper_number_hi << 4) | mapper_number_lo
      end
    end
  end
end
