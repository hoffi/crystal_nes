module CrystalNes
  class Controller < BusDevice
    enum Button : UInt8
      A      = 0x80_u8
      B      = 0x40_u8
      Select = 0x20_u8
      Start  = 0x10_u8
      Up     = 0x08_u8
      Down   = 0x04_u8
      Left   = 0x02_u8
      Right  = 0x01_u8
    end

    getter state, latched_state
    setter state

    def initialize(initial_value = 0_u8)
      @state = Bytes.new(2, initial_value)
      @latched_state = Bytes.new(2, initial_value)
    end

    def reset!
      @state = Bytes.new(2, 0_u8)
    end

    def press_button!(port, button : Button)
      @state[port] |= button.value
    end

    ##########################
    # Bus interface
    def read(address, debug = false)
      value = @latched_state[address].bit(7)
      @latched_state[address] <<= 1 unless debug
      value
    end

    def write(address, value)
      return 0_u8 if value == 0_u8
      # When the written value is not zero, fill the latch state with the
      # current state.
      @latched_state = @state.dup
    end
    ##########################
  end
end
