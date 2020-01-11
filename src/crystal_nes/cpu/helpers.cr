module CrystalNes
  class Cpu
    module Helpers
      @[AlwaysInline]
      def read16(address)
        (@bus.read(address + 1).to_u16 << 8) | @bus.read(address)
      end

      @[AlwaysInline]
      def read16_bug(address)
        (@bus.read((address.to_u8 &+ 1_u8).to_u16).to_u16 << 8) |
          @bus.read(address)
      end

      @[AlwaysInline]
      def push(value : UInt16)
        push(((value & 0xFF00) >> 8).to_u8)
        push((value & 0x00FF).to_u8)
      end

      @[AlwaysInline]
      def push(value : UInt8)
        @bus.write((0x100_u16 | @sp), value)
        @sp &-= 1
      end

      @[AlwaysInline]
      def pop16
        addr1 = pop8
        addr2 = pop8
        (addr2.to_u16 << 8) | addr1
      end

      @[AlwaysInline]
      def pop8
        @sp &+= 1
        @bus.read(0x100_u16 | @sp)
      end

      @[AlwaysInline]
      def page_crossed?(a, b); (a & 0xFF00) != (b & 0xFF00); end
    end
  end
end
