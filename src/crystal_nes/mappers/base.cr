module CrystalNes
  module Mappers
    class Base
      def initialize(cartridge : CrystalNes::Cartridge)
        @cartridge = cartridge
      end

      def read(address)
        0_u8
      end
      def write(address, value)
        0_u8
      end

      def mirror_mode
        @cartridge.mirror
      end
    end
  end
end
