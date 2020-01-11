module CrystalNes
  module MapperBackend
    abstract class Base
      @mirror_mode : MirrorMode
      getter mirror_mode

      abstract def read(address, debug = false)
      abstract def write(address, data)

      def initialize(rom_data)
        @mirror_mode = rom_data.mirror_mode
      end
    end
  end
end
