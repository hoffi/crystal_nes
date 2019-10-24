module CrystalNes
  class Controller
    def initialize
      @state = Bytes.new(2, 0_u8)
      @internal_state = Bytes.new(2, 0_u8)
    end

    def read(addr)
      data = (@state[addr] & 0x80) > 0 ? 1_u8 : 0_u8
      @state[addr] <<= 1;
      data
    end

    def write(addr, value)
      return if value == 0
      @state[addr] = @internal_state[addr]
    end

    def reset_state
      @internal_state = Bytes.new(2, 0_u8)
    end

    def set_key(controller, value)
      @internal_state[controller] |= value.to_u8
    end
  end
end
