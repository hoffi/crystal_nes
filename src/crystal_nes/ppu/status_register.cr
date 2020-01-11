require "bitfields"

module CrystalNes
  class Ppu < BusDevice
    class StatusRegister < BitFields
      bf unused : UInt8, 5
      bf sprite_overflow : UInt8, 1
      bf sprite_zero_hit : UInt8, 1
      bf vblank : UInt8, 1

      def to_u8
        to_slice[0]
      end
    end
  end
end
