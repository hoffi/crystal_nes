module CrystalNes
  class Ram
    @ram : IO::Memory
    getter ram

    def initialize
      @ram = IO::Memory.new(2 * 1024)
      @ram.write(Bytes.new(2 * 1024, 0_u8))
    end

    def read(address)
      @ram.pos = address
      @ram.read_bytes(UInt8)
    end

    def write(address, value)
      @ram.pos = address
      @ram.write_byte(value)
    end
  end
end
