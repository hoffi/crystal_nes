require "cray"

module CrystalNes
  class Gui
    alias Button = CrystalNes::Controller::Button

    def initialize(@console : CrystalNes::Console)
      LibRay.init_window 512, 480, "NES"
      LibRay.set_target_fps 60
      @run = true

      @game_view = LibRay.load_render_texture(256, 240)
      @console.on_swap_pixel_buffer do |raw_buffer|
        cray_color_buffer = raw_buffer.map { |c| LibRay.get_color(c) }
        LibRay.update_texture(@game_view.texture, cray_color_buffer)
      end
    end

    def main_loop
      controller = @console.controller

      while !LibRay.window_should_close?
        @console.step_by_frame if @run

        LibRay.begin_drawing
        LibRay.clear_background(LibRay::BLACK)
        LibRay.draw_texture_ex(
          @game_view.texture,
          LibRay::Vector2.new(x: 0, y: 0),
          0,
          2,
          LibRay::WHITE
        )
        LibRay.end_drawing

        controller.reset!

        if LibRay.key_pressed?(LibRay::KEY_SPACE)
          @run = !@run
        elsif LibRay.key_pressed?(LibRay::KEY_R)
          @console.reset!
        elsif LibRay.key_down?(LibRay::KEY_Y) || LibRay.key_down?(LibRay::KEY_Z)
          controller.press_button!(0, Button::A)
        elsif LibRay.key_down?(LibRay::KEY_X)
          controller.press_button!(0, Button::B)
        elsif LibRay.key_down?(LibRay::KEY_A)
          controller.press_button!(0, Button::Select)
        elsif LibRay.key_down?(LibRay::KEY_S)
          controller.press_button!(0, Button::Start)
        elsif LibRay.key_down?(LibRay::KEY_UP)
          controller.press_button!(0, Button::Up)
        elsif LibRay.key_down?(LibRay::KEY_DOWN)
          controller.press_button!(0, Button::Down)
        elsif LibRay.key_down?(LibRay::KEY_LEFT)
          controller.press_button!(0, Button::Left)
        elsif LibRay.key_down?(LibRay::KEY_RIGHT)
          controller.press_button!(0, Button::Right)
        end
      end

      close
    end

    def close
      LibRay.unload_render_texture(@game_view)
      LibRay.close_window
    end
  end
end
