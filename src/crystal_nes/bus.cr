# http://wiki.nesdev.com/w/index.php/CPU_memory_map
module CrystalNes
  class Bus
    def initialize(@mapper : Mapper, @ppu : Ppu, @controller : Controller)
      # 2 KB of internal ram
      @internal_ram = Bytes.new(2048, 0)
    end

    def read(address, debug = false)
      if address < 0x2000
        # The internal ram is mirrored 4 times every 2 KB (0x0000 - 0x2000)
        @internal_ram[address % 0x0800]
      elsif address >= 0x2000 && address < 0x4000
        @ppu.read((address & 0x0007) + 0x2000, debug)
      elsif address >= 0x4000 && address < 0x4016
        0_u8 # TODO: APU Registers
      elsif address >= 0x4016 && address < 0x4018
        @controller.read(address & 1)
      elsif address >= 0x4018 && address < 0x4020
        0_u8 # TODO: APU Registers
      else
        @mapper.read(address, debug)
      end
    end

    def write(address, data)
      if address < 0x2000
        # The internal ram is mirrored 4 times every 2 KB (0x0000 - 0x2000)
        @internal_ram[address % 0x0800] = data
      elsif address >= 0x2000 && address < 0x4000
        @ppu.write((address & 0x0007) + 0x2000, data)
      elsif address >= 0x4000 && address < 0x4016
        0_u8 # TODO: APU Registers
      elsif address >= 0x4016 && address < 0x4018
        @controller.write(address & 1, data)
      elsif address >= 0x4018 && address < 0x4020
        0_u8 # TODO: APU Registers
      else
        @mapper.write(address, data)
      end
    end

    def ram_dump!(only = nil)
      dump = IO::Hexdump.new(IO::Memory.new(@internal_ram, false), output:
                             STDOUT, read: true)
      if only.nil?
        dump.read(@internal_ram)
      else
        dump.read(Bytes.new(only.as(Int), 0_u8))
      end
      dump.close
    end
  end
end
