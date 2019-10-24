module CrystalNes
  class Console
    getter :ppu, :cpu, :controller

    @mapper : Mappers::Base

    def initialize(@cartridge : Cartridge)
      @controller = CrystalNes::Controller.new
      @mapper = initialize_mapper(@cartridge.mapper_number)
      @memory = CrystalNes::Memory.new(@mapper, @controller)
      @cpu = CrystalNes::Cpu.new(@memory)
      @ppu = CrystalNes::Ppu.new(@mapper, @cpu)
      @memory.ppu = @ppu
    end

    def step
      cpu_cycles = @cpu.step

      ppu_cycles = cpu_cycles * 3
      ppu_cycles.times { @ppu.step }
    end

    def step_by_frame
      29781.times { step }
    end

    def dump_memory
      io = IO::Hexdump.new(@memory.ram.ram, output: STDOUT, read: true)
      bytes = Bytes.new(2048)
      io.read(bytes)
      io.close
    end

    def game_view
      @ppu.front.texture
    end

    private def initialize_mapper(number)
      case number
      when 0 then Mappers::Mapper0.new(@cartridge)
      else raise "Unknown mapper #{number}!"
      end
    end
  end
end
