module CrystalNes
  class Ppu < BusDevice
    module MainBusInterface
      def read(address, debug = false)
        case address
        when 0x2002 then
          data = (@status.to_u8 & 0xE0) | (@ppu_data_buffer & 0x1F)
          return data if debug
          @status.vblank = 0
          @write_toggle = false
          @register_latch = data
        when 0x2004 then
          data = @oam[@oam_address]
          @oam_address &+= 1 if @status.vblank == 0 && !debug
          data
        when 0x2007 then
          addr = @v.to_u16
          data = @ppu_data_buffer.dup

          unless debug
            @ppu_data_buffer = @bus.read(addr, debug)
            @v.from_u16(addr &+ (@control.increment_mode == 1 ? 32 : 1))
          end

          value =
            if addr >= 0x3F00
              x = @ppu_data_buffer.dup & (@mask.greyscale == 1 ? 0x30 : 0x3F)
              unless debug
                @ppu_data_buffer = @bus.read(addr - 0x0F00, debug)
              end
              x
            else
              data
            end
          @register_latch = value unless debug
          value
        else
          # Write-only registers just return the last registers value.
          @register_latch
        end
      end

      def write(address, data)
        case address
        when 0x2000 then
          if @status.vblank == 1 && @control.nmi_enable == 0 && data.bit(7) == 1
            @nmi_delay = 0
            @nmi_triggered = true
          end
          @control = Ppu::ControlRegister.new(Bytes[data])
          @t.nametable_x = @control.nametable_x
          @t.nametable_y = @control.nametable_y
        when 0x2001 then
          @mask = Ppu::MaskRegister.new(Bytes[data])
        when 0x2003 then
          @oam_address = data
        when 0x2004 then
          @oam[@oam_address] = data
          @oam_address &+= 1
        when 0x2005 then
          if @write_toggle
            @t.fine_y = data & 7
            @t.coarse_y = data >> 3
            @write_toggle = false
          else
            @x_scroll = data & 7
            @t.coarse_x = data >> 3
            @write_toggle = true
          end
        when 0x2006 then
          if @write_toggle
            @t.from_u16((@t.to_u16 & 0xFF00) | data)
            @v = @t.dup
            @write_toggle = false
          else
            @t.from_u16(((data & 0x3F).to_u16 << 8) | (@t.to_u16 & 0x00FF))
            @write_toggle = true
          end
        when 0x2007 then
          addr = @v.to_u16
          @bus.write(addr, data)
          @v.from_u16(addr &+ (@control.increment_mode == 1 ? 32 : 1))
        when 0x4014 then
          start_addr = data.to_u16 << 8
          256.times do |i|
            @oam[@oam_address] = @main_bus.read(start_addr + i, false)
            @oam_address &+= 1
          end

          @oam_dma_handler.call
        end
        @register_latch = data
      end
    end
  end
end
