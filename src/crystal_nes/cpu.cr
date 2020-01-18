require "./cpu/helpers"
require "./cpu/addressing_modes"
require "./cpu/instructions/*"

module CrystalNes
  class Cpu
    include Helpers

    include AddressingModes

    include BranchInstructions
    include FlagInstructions
    include MoveInstructions
    include ArithmeticInstructions
    include IllegalInstructions

    @pc : UInt16
    @pending_interrupt : Symbol?

    getter p, pc, sp, a, x, y, cycles
    setter pending_interrupt, delay

    def initialize(@bus : Bus)
      @cycles = 0
      @pending_interrupt = nil
      @delay = 0

      # Program Counter (pc) and Stack Pointer (sp)
      @pc = 0_u16
      @sp = 0xFD_u8

      # Registers
      @a = 0_u8
      @x = 0_u8
      @y = 0_u8
      @p = Cpu::StatusRegister.new
    end

    def power_up!
      # See http://wiki.nesdev.com/w/index.php/CPU_power_up_state#At_power-up
      # for these initial values
      @pc = reset_vector
      @p.from_value(0x34_u8)
    end

    def reset!
      # See http://wiki.nesdev.com/w/index.php/CPU_power_up_state#After_reset
      @pc = reset_vector
      @sp -= 3
      @delay = 0
      @p.interupt_disable = true
    end

    @[AlwaysInline]
    def reset_vector; (@bus.read(0xFFFD).to_u16 << 8) | @bus.read(0xFFFC); end

    @[AlwaysInline]
    def nmi_vector; (@bus.read(0xFFFB).to_u16 << 8) | @bus.read(0xFFFA); end

    @[AlwaysInline]
    def irq_vector; (@bus.read(0xFFFF).to_u16 << 8) | @bus.read(0xFFFE); end

    def step
      # Reset cycle counter
      @cycles = 0

      # If a delay is set, skip execution and decrement the counter until zero.
      if @delay > 0
        @delay -= 1
        return @cycles
      end

      # Handle interupts first if one is pending.
      if @pending_interrupt == :nmi
        nmi
      elsif @pending_interrupt == :irq
        irq
      end
      @pending_interrupt = nil

      # Read the opcode at the current program counter
      opcode = @bus.read(@pc)
      @pc += 1
      execute(opcode)

      @cycles
    end

    def nmi
      @cycles += 7
      push(@pc)
      push(@p.to_u8)
      @pc = nmi_vector
    end

    def irq
      return if @p.interupt_disable
      @cycles += 7
      push(@pc)
      push(@p.to_u8)
      @pc = irq_vector
      @p.interupt_disable = true
    end

    def brk
      @cycles += 7
      push(@pc)
      push(@p.to_u8)
      @pc = irq_vector
      @p.break_flag = true
      @p.interupt_disable = true
    end

    def hlt; @pc -= 1; end

    @[AlwaysInline]
    def execute(opcode)
      case opcode
      when 0x00 then brk
      when 0x01 then ora(@bus.read(load_indirect_x))
      when 0x02 then hlt
      when 0x03 then slo(load_indirect_x)
      when 0x04 then nop(load_zero_page)
      when 0x05 then ora(@bus.read(load_zero_page))
      when 0x06 then asl(load_zero_page)
      when 0x07 then slo(load_zero_page)
      when 0x08 then php
      when 0x09 then ora(load_immediate)
      when 0x0A then asl
      when 0x0B then and(load_immediate); asl; @cycles -= 2
      when 0x0C then nop(load_absolute)
      when 0x0D then ora(@bus.read(load_absolute))
      when 0x0E then asl(load_absolute)
      when 0x0F then slo(load_absolute)
      when 0x10 then bpl(load_relative)
      when 0x11 then ora(@bus.read(load_indirect_y))
      when 0x12 then hlt
      when 0x13 then slo(load_indirect_y)
      when 0x14 then nop(load_zero_page_x)
      when 0x15 then ora(@bus.read(load_zero_page_x))
      when 0x16 then asl(load_zero_page_x)
      when 0x17 then slo(load_zero_page_x)
      when 0x18 then clc
      when 0x19 then ora(@bus.read(load_absolute_y))
      when 0x1A then nop
      when 0x1B then slo(load_absolute_y)
      when 0x1C then nop(load_absolute_x)
      when 0x1D then ora(@bus.read(load_absolute_x))
      when 0x1E then asl(load_absolute_x)
      when 0x1F then slo(load_absolute_x(false))
      when 0x20 then jsr(load_absolute)
      when 0x21 then and(@bus.read(load_indirect_x))
      when 0x22 then hlt
      when 0x23 then rla(load_indirect_x)
      when 0x24 then bit(@bus.read(load_zero_page))
      when 0x25 then and(@bus.read(load_zero_page))
      when 0x26 then rol(load_zero_page)
      when 0x27 then rla(load_zero_page)
      when 0x28 then plp
      when 0x29 then and(load_immediate)
      when 0x2A then rol
      when 0x2B then and(load_immediate); rol; @cycles -= 2
      when 0x2C then bit(@bus.read(load_absolute))
      when 0x2D then and(@bus.read(load_absolute))
      when 0x2E then rol(load_absolute)
      when 0x2F then rla(load_absolute)
      when 0x30 then bmi(load_relative)
      when 0x31 then and(@bus.read(load_indirect_y))
      when 0x32 then hlt
      when 0x33 then rla(load_indirect_y)
      when 0x34 then nop(load_zero_page_x)
      when 0x35 then and(@bus.read(load_zero_page_x))
      when 0x36 then rol(load_zero_page_x)
      when 0x37 then rla(load_zero_page_x)
      when 0x38 then sec
      when 0x39 then and(@bus.read(load_absolute_y))
      when 0x3A then nop
      when 0x3B then rla(load_absolute_y)
      when 0x3C then nop(load_absolute_x)
      when 0x3D then and(@bus.read(load_absolute_x))
      when 0x3E then rol(load_absolute_x)
      when 0x3F then rla(load_absolute_x(false))
      when 0x40 then rti
      when 0x41 then eor(@bus.read(load_indirect_x))
      when 0x42 then hlt
      when 0x43 then sre(load_indirect_x)
      when 0x44 then nop(load_zero_page)
      when 0x45 then eor(@bus.read(load_zero_page))
      when 0x46 then lsr(load_zero_page)
      when 0x47 then sre(load_zero_page)
      when 0x48 then pha
      when 0x49 then eor(load_immediate)
      when 0x4A then lsr
      when 0x4B then and(load_immediate); lsr; @cycles -= 2
      when 0x4C then jmp(load_absolute)
      when 0x4D then eor(@bus.read(load_absolute))
      when 0x4E then lsr(load_absolute)
      when 0x4F then sre(load_absolute)
      when 0x50 then bvc(load_relative)
      when 0x51 then eor(@bus.read(load_indirect_y))
      when 0x52 then hlt
      when 0x53 then sre(load_indirect_y)
      when 0x54 then nop(load_zero_page_x)
      when 0x55 then eor(@bus.read(load_zero_page_x))
      when 0x56 then lsr(load_zero_page_x)
      when 0x57 then sre(load_zero_page_x)
      when 0x58 then cli
      when 0x59 then eor(@bus.read(load_absolute_y))
      when 0x5A then nop
      when 0x5B then sre(load_absolute_y)
      when 0x5C then nop(load_absolute_x)
      when 0x5D then eor(@bus.read(load_absolute_x))
      when 0x5E then lsr(load_absolute_x)
      when 0x5F then sre(load_absolute_x(false))
      when 0x60 then rts
      when 0x61 then adc(@bus.read(load_indirect_x))
      when 0x62 then hlt
      when 0x63 then rra(load_indirect_x)
      when 0x64 then nop(load_zero_page)
      when 0x65 then adc(@bus.read(load_zero_page))
      when 0x66 then ror(load_zero_page)
      when 0x67 then rra(load_zero_page)
      when 0x68 then pla
      when 0x69 then adc(load_immediate)
      when 0x6A then ror
      when 0x6B then and(load_immediate); ror; @cycles -= 2
      when 0x6C then jmp(load_indirect)
      when 0x6D then adc(@bus.read(load_absolute))
      when 0x6E then ror(load_absolute)
      when 0x6F then rra(load_absolute)
      when 0x70 then bvs(load_relative)
      when 0x71 then adc(@bus.read(load_indirect_y))
      when 0x72 then hlt
      when 0x73 then rra(load_indirect_y)
      when 0x74 then nop(load_zero_page_x)
      when 0x75 then adc(@bus.read(load_zero_page_x))
      when 0x76 then ror(load_zero_page_x)
      when 0x77 then rra(load_zero_page_x)
      when 0x78 then sei
      when 0x79 then adc(@bus.read(load_absolute_y))
      when 0x7A then nop
      when 0x7B then rra(load_absolute_y)
      when 0x7C then nop(load_absolute_x)
      when 0x7D then adc(@bus.read(load_absolute_x))
      when 0x7E then ror(load_absolute_x)
      when 0x7F then rra(load_absolute_x(false))
      when 0x80 then nop(load_immediate)
      when 0x81 then sta(load_indirect_x)
      when 0x82 then nop(load_immediate)
      when 0x83 then sax(load_indirect_x)
      when 0x84 then sty(load_zero_page)
      when 0x85 then sta(load_zero_page)
      when 0x86 then stx(load_zero_page)
      when 0x87 then sax(load_zero_page)
      when 0x88 then dey
      when 0x89 then nop(load_immediate)
      when 0x8A then txa
      when 0x8B then txa; and(load_immediate); @cycles -= 2
      when 0x8C then sty(load_absolute)
      when 0x8D then sta(load_absolute)
      when 0x8E then stx(load_absolute)
      when 0x8F then sax(load_absolute)
      when 0x90 then bcc(load_relative)
      when 0x91 then sta(load_indirect_y(false))
      when 0x92 then hlt
      when 0x94 then sty(load_zero_page_x)
      when 0x95 then sta(load_zero_page_x)
      when 0x96 then stx(load_zero_page_y)
      when 0x97 then sax(load_zero_page_y)
      when 0x98 then tya
      when 0x99 then sta(load_absolute_y(false))
      when 0x9A then txs
      when 0x9D then sta(load_absolute_x(false))
      when 0xA0 then ldy(load_immediate)
      when 0xA1 then lda(@bus.read(load_indirect_x))
      when 0xA2 then ldx(load_immediate)
      when 0xA3 then lax(@bus.read(load_indirect_x))
      when 0xA4 then ldy(@bus.read(load_zero_page))
      when 0xA5 then lda(@bus.read(load_zero_page))
      when 0xA6 then ldx(@bus.read(load_zero_page))
      when 0xA7 then lax(@bus.read(load_zero_page))
      when 0xA8 then tay
      when 0xA9 then lda(load_immediate)
      when 0xAA then tax
      when 0xAB then lax(load_immediate); tax; @cycles -= 4
      when 0xAC then ldy(@bus.read(load_absolute))
      when 0xAD then lda(@bus.read(load_absolute))
      when 0xAE then ldx(@bus.read(load_absolute))
      when 0xAF then lax(@bus.read(load_absolute))
      when 0xB0 then bcs(load_relative)
      when 0xB1 then lda(@bus.read(load_indirect_y))
      when 0xB2 then hlt
      when 0xB3 then lax(@bus.read(load_indirect_y))
      when 0xB4 then ldy(@bus.read(load_zero_page_x))
      when 0xB5 then lda(@bus.read(load_zero_page_x))
      when 0xB6 then ldx(@bus.read(load_zero_page_y))
      when 0xB7 then lax(@bus.read(load_zero_page_y))
      when 0xB8 then clv
      when 0xB9 then lda(@bus.read(load_absolute_y))
      when 0xBA then tsx
      when 0xBC then ldy(@bus.read(load_absolute_x))
      when 0xBD then lda(@bus.read(load_absolute_x))
      when 0xBE then ldx(@bus.read(load_absolute_y))
      when 0xBF then lax(@bus.read(load_absolute_y))
      when 0xC0 then cpy(load_immediate)
      when 0xC1 then cmp(@bus.read(load_indirect_x))
      when 0xC2 then nop(load_immediate)
      when 0xC3 then dcp(load_indirect_x)
      when 0xC4 then cpy(@bus.read(load_zero_page))
      when 0xC5 then cmp(@bus.read(load_zero_page))
      when 0xC6 then dec(load_zero_page)
      when 0xC7 then dcp(load_zero_page)
      when 0xC8 then iny
      when 0xC9 then cmp(load_immediate)
      when 0xCA then dex
      when 0xCC then cpy(@bus.read(load_absolute))
      when 0xCD then cmp(@bus.read(load_absolute))
      when 0xCE then dec(load_absolute)
      when 0xCF then dcp(load_absolute)
      when 0xD0 then bne(load_relative)
      when 0xD1 then cmp(@bus.read(load_indirect_y))
      when 0xD2 then hlt
      when 0xD3 then dcp(load_indirect_y)
      when 0xD4 then nop(load_zero_page_x)
      when 0xD5 then cmp(@bus.read(load_zero_page_x))
      when 0xD6 then dec(load_zero_page_x)
      when 0xD7 then dcp(load_zero_page_x)
      when 0xD8 then cld
      when 0xD9 then cmp(@bus.read(load_absolute_y))
      when 0xDA then nop
      when 0xDB then dcp(load_absolute_y)
      when 0xDC then nop(load_absolute_x)
      when 0xDD then cmp(@bus.read(load_absolute_x))
      when 0xDE then dec(load_absolute_x(false))
      when 0xDF then dcp(load_absolute_x(false))
      when 0xE0 then cpx(load_immediate)
      when 0xE1 then sbc(@bus.read(load_indirect_x))
      when 0xE2 then nop(load_immediate)
      when 0xE3 then isc(load_indirect_x)
      when 0xE4 then cpx(@bus.read(load_zero_page))
      when 0xE5 then sbc(@bus.read(load_zero_page))
      when 0xE6 then inc(load_zero_page)
      when 0xE7 then isc(load_zero_page)
      when 0xE8 then inx
      when 0xE9 then sbc(load_immediate)
      when 0xEA then nop
      when 0xEB then sbc(load_immediate)
      when 0xEC then cpx(@bus.read(load_absolute))
      when 0xED then sbc(@bus.read(load_absolute))
      when 0xEE then inc(load_absolute)
      when 0xEF then isc(load_absolute)
      when 0xF0 then beq(load_relative)
      when 0xF1 then sbc(@bus.read(load_indirect_y))
      when 0xF2 then hlt
      when 0xF3 then isc(load_indirect_y)
      when 0xF4 then nop(load_zero_page_x)
      when 0xF5 then sbc(@bus.read(load_zero_page_x))
      when 0xF6 then inc(load_zero_page_x)
      when 0xF7 then isc(load_zero_page_x)
      when 0xF8 then sed
      when 0xF9 then sbc(@bus.read(load_absolute_y))
      when 0xFA then nop
      when 0xFB then isc(load_absolute_y)
      when 0xFC then nop(load_absolute_x)
      when 0xFD then sbc(@bus.read(load_absolute_x))
      when 0xFE then inc(load_absolute_x(false))
      when 0xFF then isc(load_absolute_x(false))
      else raise ArgumentError.new("Unknown opcode #{opcode.to_s(16, true)}!")
      end
    end
  end
end
