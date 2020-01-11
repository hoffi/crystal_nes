module CrystalNes
  class Ppu < BusDevice
    class LoopyRegister < BitFields
      bf coarse_x : UInt8, 5
      bf coarse_y : UInt8, 5
      bf nametable_x : UInt8, 1
      bf nametable_y : UInt8, 1
      bf fine_y : UInt8, 3
      bf unused : UInt8, 1

      def from_u16(value : UInt16)
        @coarse_x = value.bits(0..4).to_u8
        @coarse_y = value.bits(5..9).to_u8
        @nametable_x = value.bit(10).to_u8
        @nametable_y = value.bit(11).to_u8
        @fine_y = value.bits(12..14).to_u8
        @unused = value.bit(15).to_u8
      end

      def to_u16
        (@coarse_x.to_u16 << 0) |
          (@coarse_y.to_u16 << 5) |
          (@nametable_x.to_u16 << 10) |
          (@nametable_y.to_u16 << 11) |
          (@fine_y.to_u16 << 12) |
          (@unused.to_u16 << 15)
      end
    end
  end
end
