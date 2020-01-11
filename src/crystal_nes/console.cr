module CrystalNes
  class Console
    getter cpu, ppu, bus, controller
    setter cpu

    def initialize
      @mapper = Mapper.new
      @ppu = Ppu.new(@mapper)
      @controller = Controller.new

      @bus = Bus.new(@mapper, @ppu, @controller)
      @cpu = Cpu.new(@bus)
    end

    def on_swap_pixel_buffer(&block : Ppu::PixelBuffer -> Void)
      @ppu.swap_pixel_buffer_callback = block
    end

    def insert_rom_file(rom_path)
      rom_data = File.open(rom_path, "rb").read_bytes(FileFormats::Nes)
      @mapper.prepare_mapper(rom_data)
      @cpu.power_up!
    end

    def step
      cpu_cycles = @cpu.step

      # Handle NMIs triggered by a CPU write to the PPU
      handle_nmi

      (cpu_cycles * 3).times do
        @ppu.step
        break if handle_nmi
      end

      cpu_cycles
    end

    def reset!
      @cpu.reset!
    end

    def step_by_frame
      # http://wiki.nesdev.com/w/index.php/Cycle_reference_chart#Clock_rates
      cycles_per_frame = 29781
      while cycles_per_frame > 0
        cycles_per_frame -= step
      end
    end

    private def handle_nmi
      if @ppu.nmi_triggered
        @ppu.nmi_triggered = false
        @cpu.pending_interrupt = :nmi
        true
      else
        false
      end
    end
  end
end
