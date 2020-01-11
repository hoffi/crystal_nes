require "bitfields"

module CrystalNes
  class Ppu < BusDevice
    class ControlRegister < BitFields
      bf nametable_x : UInt8, 1
      bf nametable_y : UInt8, 1
      bf increment_mode : UInt8, 1
      bf sprite_tile : UInt8, 1
      bf background_tile : UInt8, 1
      bf sprite_height : UInt8, 1
      bf slave_mode : UInt8, 1 # Unused
      bf nmi_enable : UInt8, 1

      def to_u8
        to_slice[0]
      end
    end
  end
end
