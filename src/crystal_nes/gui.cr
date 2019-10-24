require "cray"
require "io/hexdump"

module CrystalNes
  class GUI
    def initialize(@console : CrystalNes::Console)
      LibRay.init_window 1035, 480, "NES" # + Debugs
      LibRay.set_target_fps 60
      @run = false
      @step = false
      @console.ppu.init_front_buffer()
    end

    def main_loop
      pattern1 = LibRay.load_render_texture(128, 128)
      pattern2 = LibRay.load_render_texture(128, 128)
      time = 0

      while !LibRay.window_should_close?
        LibRay.begin_drawing
        LibRay.clear_background(LibRay::BLACK)

        if @step || @run
          if @step
            @console.step
            @step = false
          else
            @console.step_by_frame
          end
        end

        LibRay.draw_texture_ex(@console.game_view, LibRay::Vector2.new(x: 0, y: 0), 0, 2, LibRay::WHITE)

        LibRay.draw_text(
          "STATUS: N V - B D I Z C",
          516, 5, 9, LibRay::WHITE
        )

        render_flag("N", Cpu::CpuFlags::Negative, 566)
        render_flag("V", Cpu::CpuFlags::Overflow, 577)
        render_flag("B", Cpu::CpuFlags::Break, 598)
        render_flag("D", Cpu::CpuFlags::Decimal, 609)
        render_flag("I", Cpu::CpuFlags::InteruptDisable, 620)
        render_flag("Z", Cpu::CpuFlags::Zero, 628)
        render_flag("C", Cpu::CpuFlags::Carry, 639)

        LibRay.draw_text(
          "PC: #{Utils.hex(@console.cpu.pc)}  SP: #{Utils.hex(@console.cpu.sp)}",
          516, 18, 9, LibRay::WHITE
        )

        LibRay.draw_text(
          "A: #{Utils.hex(@console.cpu.a)} [#{@console.cpu.a}]", 516, 31, 9, LibRay::WHITE
        )

        LibRay.draw_text(
          "X: #{Utils.hex(@console.cpu.x)} [#{@console.cpu.x}]", 516, 44, 9, LibRay::WHITE
        )

        LibRay.draw_text(
          "Y: #{Utils.hex(@console.cpu.y)} [#{@console.cpu.y}]", 516, 57, 9, LibRay::WHITE
        )

        LibRay.draw_text("Instructions:", 516, 80, 9, LibRay::WHITE)

        8.times do |i|
          LibRay.draw_text(
            @console.cpu.debug_infos[i],
            526, (93 + (13 * i)), 9, (i == 7 ? LibRay::GREEN : LibRay::WHITE)
          )
        end

        LibRay.draw_text("Palettes:", 516, 150, 9, LibRay::WHITE)

        4.times do |i|
          LibRay.draw_text(i.to_s, 525 + (60 * i), 165, 9, LibRay::WHITE)

          colors = @console.ppu.get_palette_colors(i)
          colors.each.with_index do |raw, idx|
            color = LibRay.get_color(raw)
            LibRay.draw_rectangle(535 + (10 * idx) + (60 * i), 165, 9, 9, color)
          end
        end

        4.times do |i|
          LibRay.draw_text((i + 4).to_s, 525 + (60 * i), 175, 9, LibRay::WHITE)

          colors = @console.ppu.get_palette_colors(i + 4)
          colors.each.with_index do |raw, idx|
            color = LibRay.get_color(raw)
            LibRay.draw_rectangle(535 + (10 * idx) + (60 * i), 175, 9, 9, color)
          end
        end

        LibRay.draw_text("Pattern Tables:", 516, 200, 9, LibRay::WHITE)

        @console.ppu.draw_pattern_table(0_u16, 0_u8, pattern1.texture)
        LibRay.draw_texture_ex(pattern1.texture, LibRay::Vector2.new(x: 516, y: 216), 0, 2, LibRay::WHITE)
        @console.ppu.draw_pattern_table(1_u16, 0_u8, pattern2.texture)
        LibRay.draw_texture_ex(pattern2.texture, LibRay::Vector2.new(x: 775, y: 216), 0, 2, LibRay::WHITE)

        LibRay.draw_rectangle(779, 154, 161, 41, LibRay::GRAY)
        x = 0
        y = 0
        CrystalNes::Palette::PALETTE.each do |color|
          color = LibRay.get_color(color)
          LibRay.draw_rectangle(780 + (10 * x), 155 + (10 * y), 9, 9, color)
          if x >= 15
            x = 0
            y += 1
          else
            x += 1
          end
        end

        LibRay.end_drawing

        @console.controller.reset_state
        if LibRay.key_pressed?(LibRay::KEY_SPACE)
          @run = !@run
          @step = false
        elsif LibRay.key_pressed?(LibRay::KEY_ENTER)
          @run = false
          @step = true
        elsif LibRay.key_pressed?(LibRay::KEY_P)
          socket = IO::Memory.new(@console.ppu.memory.palette_data)
          io = IO::Hexdump.new(socket, output: STDOUT, read: true)
          io.read(@console.ppu.memory.palette_data)
          io.close
        elsif LibRay.key_pressed?(LibRay::KEY_N)
          puts "Nametable 1:"
          socket = IO::Memory.new(@console.ppu.memory.name_table[0])
          io = IO::Hexdump.new(socket, output: STDOUT, read: true)
          io.read(@console.ppu.memory.name_table[0])
          io.close
          puts "Nametable 2:"
          socket = IO::Memory.new(@console.ppu.memory.name_table[1])
          io = IO::Hexdump.new(socket, output: STDOUT, read: true)
          io.read(@console.ppu.memory.name_table[1])
          io.close
        elsif LibRay.key_down?(LibRay::KEY_Y) || LibRay.key_down?(LibRay::KEY_Z) @console.controller.set_key(0, 0x80)
        elsif LibRay.key_down?(LibRay::KEY_X) @console.controller.set_key(0, 0x40)
        elsif LibRay.key_down?(LibRay::KEY_A) @console.controller.set_key(0, 0x20)
        elsif LibRay.key_down?(LibRay::KEY_S) @console.controller.set_key(0, 0x10)
        elsif LibRay.key_down?(LibRay::KEY_UP) @console.controller.set_key(0, 0x08)
        elsif LibRay.key_down?(LibRay::KEY_DOWN) @console.controller.set_key(0, 0x04)
        elsif LibRay.key_down?(LibRay::KEY_LEFT) @console.controller.set_key(0, 0x02)
        elsif LibRay.key_down?(LibRay::KEY_RIGHT) @console.controller.set_key(0, 0x01)
        end
      end
    end

    def render_flag(char, ftype, pos)
      if (@console.cpu.flags & ftype) == Cpu::CpuFlags::None
        LibRay.draw_text(char, pos, 5, 9, LibRay::GREEN)
      else
        LibRay.draw_text(char, pos, 5, 9, LibRay::RED)
      end
    end

    def close
      LibRay.unload_render_texture(@console.ppu.front)
      LibRay.close_window
    end
  end
end
