require "bitfields"

module CrystalNes
  class Ppu < BusDevice
    class MaskRegister < BitFields
      bf greyscale : UInt8, 1
      bf background_left_column_enable : UInt8, 1
      bf sprite_left_column_enable : UInt8, 1
      bf background_enable : UInt8, 1
      bf sprite_enable : UInt8, 1
      bf red_emphasis : UInt8, 1
      bf green_emphasis : UInt8, 1
      bf blue_emphasis : UInt8, 1

      def to_u8
        to_slice[0]
      end
    end
  end
end
