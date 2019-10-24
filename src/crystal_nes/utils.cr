module CrystalNes
  module Utils
    def self.hex(int : UInt8)
      int.to_s(16, true).rjust(2, '0')
    end

    def self.hex(int : UInt16)
      int.to_s(16, true).rjust(4, '0')
    end

    def self.hex(int : UInt32)
      int.to_s(16, true).rjust(6, '0')
    end
  end
end
