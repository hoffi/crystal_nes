module CrystalNes
  class Memory
    @ram : CrystalNes::Ram # TODO
    @ppu : CrystalNes::Ppu | Nil
    getter ram
    setter ppu

    def initialize(mapper : CrystalNes::Mappers::Base, @controller : CrystalNes::Controller)
      @mapper = mapper
      @ram = CrystalNes::Ram.new
    end

    def read(address : UInt16) : UInt8
      select_destination(address) do |target, real_address|
        target.read(real_address)
      end
    end

    def write(address : UInt16, value : UInt8)
      select_destination(address) do |target, real_address|
        target.write(real_address, value)
      end
    end

    private def select_destination(address : UInt16)
      if (0x0000..0x07FF).includes?(address)
        yield(@ram, address)
      elsif (0x0800..0x0FFF).includes?(address)
        yield(@ram, address - 0x0800)
      elsif (0x1000..0x17FF).includes?(address)
        yield(@ram, address - 0x1000)
      elsif (0x1800..0x1FFF).includes?(address)
        yield(@ram, address - 0x1800)
      elsif (0x2000..0x2007).includes?(address)
        yield(@ppu.as(CrystalNes::Ppu), address)
      elsif (0x2008..0x3FFF).includes?(address)
        yield(@ppu.as(CrystalNes::Ppu), (address & 0x0007) + 0x2000)
      elsif (0x4000..0x4017).includes?(address)
        if address == 0x4014
          yield(@ppu.as(CrystalNes::Ppu), address)
        elsif address >= 0x4016 && address <= 0x4017
          yield(@controller, address & 1)
        else
          0_u8 # TODO: APU and I/O Registers
        end
      elsif (0x4018..0x401F).includes?(address)
        0_u8 # TODO: APU and I/O functionality
      elsif (0x4020..0xFFFF).includes?(address)
        yield(@mapper, address)
      else
        0_u8
      end
    end
  end
end
