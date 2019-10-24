# TODO: Cleanup
# TODO: Debug-Support
# TODO: Specs
# TODO: Interrupts buggy
module CrystalNes
  class Cpu
    # TODO: Refactor
    @[Flags]
    enum CpuFlags : UInt8
      Carry
      Zero
      InteruptDisable
      Decimal
      Break
      Unused
      Overflow
      Negative
    end

    @flags : CpuFlags
    @pc : UInt16

    getter pc, a, x, y, sp, flags, debug_infos
    setter enable_debug

    def initialize(@memory : CrystalNes::Memory)
      # @pc = 0x8000_u16 # For Nestest
      @pc = ((@memory.read(0xFFFD).to_u16 << 8) | @memory.read(0xFFFC).to_u16)
      @a = 0_u8
      @x = 0_u8
      @y = 0_u8
      @sp = 0xFD_u8
      @flags = CpuFlags::InteruptDisable | CpuFlags::Unused
      @pending_interupt = 0
      @additional_cycles = 0
      @debug_infos = StaticArray(String, 8).new("")
      @enable_debug = false
      #@debug_addition = ""
    end

    def trigger_nmi()
      @pending_interupt = 1
    end

    def trigger_irq()
      @pending_interupt = 2
    end

    def step
      @additional_cycles = 0

      #@debug_addition = ""
      case @pending_interupt
      when 1 then nmi()
      when 2 then irq()
      end
      @pending_interupt = 0

      instruction = @memory.read(@pc)
      @pc += 1
      op = CrystalNes::INSTRUCTION_MAP[instruction]
      addr = load_args_by_addressing_mode(op)
      @pc += op[2]
      print_debug(instruction, op, addr) if @enable_debug
      op[0].call(self, addr)
      op[4] + @additional_cycles
    rescue KeyError
      if instruction
        raise "Unknown instruction #{Utils.hex(instruction)}"
      else
        raise "Instruction is nil!"
      end
    end

    def reset()
      @pc = ((@memory.read(0xFFFD).to_u16 << 8) | @memory.read(0xFFFC).to_u16)
      @flags |= CpuFlags::InteruptDisable
      @flags |= CpuFlags::Unused
      @sp = 0xFD_u8
    end

    def irq()
      if (@flags & CpuFlags::InteruptDisable) == CpuFlags::None
        push((@pc >> 8).to_u8)
        push((@pc & 0xFF).to_u8)
        php()
        @pc = ((@memory.read(0xFFFF).to_u16 << 8) | @memory.read(0xFFFE).to_u16)
        @additional_cycles = 7
      end
    end

    def nmi()
      push((@pc >> 8).to_u8)
      push((@pc & 0xFF).to_u8)
      php()
      @pc = ((@memory.read(0xFFFB).to_u16 << 8) | @memory.read(0xFFFA).to_u16)
      @additional_cycles = 7
    end

    def nop(); end
    def clc(); @flags &= ~CpuFlags::Carry; end
    def sec(); @flags |= CpuFlags::Carry; end
    def cli(); @flags &= ~CpuFlags::InteruptDisable; end
    def sei(); @flags |= CpuFlags::InteruptDisable; end
    def cld(); @flags &= ~CpuFlags::Decimal; end
    def sed(); @flags |= CpuFlags::Decimal; end
    def clv(); @flags &= ~CpuFlags::Overflow; end
    def php(); push(@flags.value | 0x10); end
    def pla(); @a = pop(); setZN(@a); end
    def pha(); push(@a); end
    def plp(); @flags = CpuFlags.new(pop() & 0xEF | 0x20); end
    def hlt(); exit(0); end
    def brk(); irq(); @additional_cycles = 0; end

    def rti()
      @flags = CpuFlags.new(pop() & 0xEF | 0x20)
      addr1 = pop().to_u16
      addr2 = pop().to_u16
      jmp(((addr2 << 8) | addr1))
    end

    def tax()
      @x = @a
      setZN(@x)
    end
    def tay()
      @y = @a
      setZN(@y)
    end
    def txa()
      @a = @x
      setZN(@a)
    end
    def tya()
      @a = @y
      setZN(@a)
    end
    def tsx()
      @x = @sp
      setZN(@x)
    end
    def txs(); @sp = @x; end

    def bcc(arg)
      if (@flags & CpuFlags::Carry) == CpuFlags::None
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def bcs(arg)
      if (@flags & CpuFlags::Carry) == CpuFlags::Carry
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def beq(arg)
      if (@flags & CpuFlags::Zero) == CpuFlags::Zero
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def bne(arg)
      if (@flags & CpuFlags::Zero) == CpuFlags::None
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def bvs(arg)
      if (@flags & CpuFlags::Overflow) == CpuFlags::Overflow
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def bvc(arg)
      if (@flags & CpuFlags::Overflow) == CpuFlags::None
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def bmi(arg)
      if (@flags & CpuFlags::Negative) == CpuFlags::Negative
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end
    def bpl(arg)
      if (@flags & CpuFlags::Negative) == CpuFlags::None
        @pc = arg
        @additional_cycles += 1
        @additional_cycles += 1 if (@pc & 0xFF00) != (arg & 0xFF00)
      end
    end

    def jmp(arg)
      @pc = arg
    end

    def jsr(arg)
      addr = @pc - 1
      push(((addr & 0xFF00) >> 8).to_u8)
      push(((addr & 0x00FF)).to_u8)
      jmp(arg)
    end

    def rts()
      addr1 = pop().to_u16
      addr2 = pop().to_u16
      jmp(((addr2 << 8) | addr1) + 1)
    end

    def bit(arg)
      data = @memory.read(arg)
      result = @a & data
      if result == 0
        @flags |= CpuFlags::Zero
      else
        @flags &= ~CpuFlags::Zero
      end
      if data.bit(7) > 0
        @flags |= CpuFlags::Negative
      else
        @flags &= ~CpuFlags::Negative
      end
      if data.bit(6) > 0
        @flags |= CpuFlags::Overflow
      else
        @flags &= ~CpuFlags::Overflow
      end
    end

    def lax(arg)
      @a = @x = @memory.read(arg)
      setZN(@a)
    end

    def sax(arg)
      @memory.write(arg, @a & @x)
    end

    def lda(arg)
      @a = @memory.read(arg)
      setZN(@a)
    end

    def ldx(arg)
      @x = @memory.read(arg)
      setZN(@x)
    end

    def ldy(arg)
      @y = @memory.read(arg)
      setZN(@y)
    end

    def sta(arg)
      @memory.write(arg, @a)
    end

    def stx(arg)
      @memory.write(arg, @x)
    end

    def sty(arg)
      @memory.write(arg, @y)
    end

    def and(arg)
      value = @a & @memory.read(arg)
      @a = value
      setZN(@a)
    end

    def ora(arg)
      value = @a | @memory.read(arg)
      @a = value
      setZN(@a)
    end

    def eor(arg)
      value = @a ^ @memory.read(arg)
      @a = value
      setZN(@a)
    end

    def cpx(arg)
      data = @memory.read(arg)
      x = @x
      value = x &- data
      setZN(value)
      if x >= data
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
    end

    def cpy(arg)
      data = @memory.read(arg)
      y = @y
      value = y &- data
      setZN(value)
      if y >= data
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
    end

    def adc(arg)
      data = @memory.read(arg)
      carry = (@flags & CpuFlags::Carry) == CpuFlags::None ? 0_u8 : 1_u8
      value = @a &+ data &+ carry
      setZN(value)
      if (@a.to_u16 &+ data.to_u16 &+ carry) > 0xFF_u8
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      if ((@a ^ data) & 0x80) == 0 && ((@a ^ value) & 0x80) != 0
        @flags |= CpuFlags::Overflow
      else
        @flags &= ~CpuFlags::Overflow
      end
      @a = value
    end

    def sbc(arg)
      data = @memory.read(arg)
      carry = (@flags & CpuFlags::Carry) == CpuFlags::None ? 0_u8 : 1_u8
      value = @a &- data &- (1 - carry)
      setZN(value)
      if (@a.to_i16 &- data.to_i16 &- (1 - carry)) >= 0_u8
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      if ((@a ^ data) & 0x80) != 0 && ((@a ^ value) & 0x80) != 0
        @flags |= CpuFlags::Overflow
      else
        @flags &= ~CpuFlags::Overflow
      end
      @a = value
    end

    def lsr()
      data = @a
      if (data & 1_u8) == 1_u8
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      value = data >> 1
      @a = value
      setZN(@a)
    end

    def lsr(arg)
      data = @memory.read(arg)
      if (data & 1_u8) == 1_u8
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      value = data >> 1
      @memory.write(arg, value)
      setZN(value)
    end

    def asl()
      data = @a
      if ((data >> 7) & 1) == 1
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      value = data << 1
      @a = value
      setZN(@a)
    end

    def asl(arg)
      data = @memory.read(arg)
      if ((data >> 7) & 1) == 1
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      value = data << 1
      @memory.write(arg, value)
      setZN(value)
    end

    def rol()
      data = @a
      carry = (@flags & CpuFlags::Carry) == CpuFlags::None ? 0_u8 : 1_u8
      if ((@a >> 7) & 1) == 1
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      @a = (@a << 1) | carry
      setZN(@a)
    end

    def rol(arg)
      data = @memory.read(arg)
      carry = (@flags & CpuFlags::Carry) == CpuFlags::None ? 0_u8 : 1_u8
      if ((data >> 7) & 1) == 1
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      value = (data << 1) | carry
      @memory.write(arg, value)
      setZN(value)
    end

    def ror()
      data = @a
      carry = (@flags & CpuFlags::Carry) == CpuFlags::None ? 0_u8 : 1_u8
      if (@a & 1) == 1
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      @a = (@a >> 1) | (carry << 7)
      setZN(@a)
    end

    def ror(arg)
      data = @memory.read(arg)
      carry = (@flags & CpuFlags::Carry) == CpuFlags::None ? 0_u8 : 1_u8
      if (data & 1) == 1
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      value = (data >> 1) | (carry << 7)
      @memory.write(arg, value)
      setZN(value)
    end

    def inx()
      @x = @x &+ 1
      setZN(@x)
    end

    def iny()
      @y = @y &+ 1
      setZN(@y)
    end

    def inc(arg)
      data = @memory.read(arg)
      value = data &+ 1
      setZN(value)
      @memory.write(arg, value)
    end

    def dex()
      @x = @x &- 1
      setZN(@x)
    end

    def dey()
      @y = @y &- 1
      setZN(@y)
    end

    def dec(arg)
      data = @memory.read(arg)
      value = data &- 1
      setZN(value)
      @memory.write(arg, value)
    end

    def cmp(arg)
      value = @a &- @memory.read(arg)
      if @a >= value
        @flags |= CpuFlags::Carry
      else
        @flags &= ~CpuFlags::Carry
      end
      setZN(value)
    end

    private def push(arg)
      @memory.write((0x100_u16 | @sp.to_u16), arg)
      @sp &-= 1
    end

    private def pop()
      @sp &+= 1
      val = @memory.read((0x100_u16 | @sp.to_u16))
      val
    end

    private def setZN(arg)
      if arg == 0
        @flags |= CpuFlags::Zero
      else
        @flags &= ~CpuFlags::Zero
      end

      if (arg >> 7) > 0
        @flags |= CpuFlags::Negative
      else
        @flags &= ~CpuFlags::Negative
      end
    end

    private def load_args_by_addressing_mode(op)
      case op[3]
      when :implied then
        # @memory.read @pc
        0_u16
      when :accumulator then
        # @memory.read @pc
        #@debug_addition = "A"
        0_u16
      when :immediate then
        x = @pc
        #@debug_addition = "\#$#{Utils.hex(@memory.read(@pc))}"
        x
      when :indirect then
        addr1 = ((@memory.read(@pc+1).to_u16 << 8) | (@memory.read(@pc).to_u16))
        addr2 = (addr1 & 0xFF00_u16) | ((addr1 & 0x00FF).to_u8 &+ 1).to_u16
        addr = ((@memory.read(addr2).to_u16 << 8) | @memory.read(addr1).to_u16)
        #@debug_addition = "($#{Utils.hex(addr1)}) = #{Utils.hex(addr)}"
        addr
      when :zero_page then
        x = @memory.read(@pc).to_u16
        #@debug_addition = "$#{Utils.hex(@memory.read(@pc))} = #{Utils.hex(@memory.read(x))}"
        x
      when :zero_page_x then
        x = (@memory.read(@pc) &+ @x).to_u16 & 0xFF
        #@debug_addition = "$#{Utils.hex(@memory.read(@pc))},X @ #{Utils.hex(x.to_u8)} = #{Utils.hex(@memory.read(x).to_u8)}"
        x
      when :zero_page_y then
        x = (@memory.read(@pc) &+ @y).to_u16 & 0xFF
        #@debug_addition = "$#{Utils.hex(@memory.read(@pc))},Y @ #{Utils.hex(x.to_u8)} = #{Utils.hex(@memory.read(x).to_u8)}"
        x
      when :relative then
        value = @memory.read(@pc).to_u16
        x =
          if value < 0x80
            (@pc + op[2]) &+ value
          else
            (@pc + op[2]) &+ (value &- 0x100)
          end
        if op[1][0] == 'B' && op[1] != "BRK" && op[1] != "BIT"
          #@debug_addition = "$#{Utils.hex(x)}"
        else
          #@debug_addition = "$#{Utils.hex(value)} = #{Utils.hex(x)}"
        end
        x
      when :absolute then
        x = ((@memory.read(@pc+1).to_u16 << 8) | @memory.read(@pc).to_u16)
        #@debug_addition = "$#{Utils.hex(x)}"
        if op[1] != "JMP" && op[1] != "JSR"
          #@debug_addition += " = #{Utils.hex(@memory.read(x))}"
        end
        x
      when :absolute_x then
        x1 = ((@memory.read(@pc+1).to_u16 << 8) | @memory.read(@pc).to_u16)
        x = x1 &+ @x
        if (x1 & 0xFF00) != (x & 0xFF00)
          @additional_cycles += 1
          # Dummy-Read
          @memory.read(x &- 0x0100)
        end
        #@debug_addition = "$#{Utils.hex(x1)},X @ #{Utils.hex(x)} = #{Utils.hex(@memory.read(x))}"
        x
      when :absolute_y then
        x1 = ((@memory.read(@pc+1).to_u16 << 8) | @memory.read(@pc).to_u16)
        x = x1 &+ @y
        if (x1 & 0xFF00) != (x & 0xFF00)
          @additional_cycles += 1
        end
        #@debug_addition = "$#{Utils.hex(x1)},Y @ #{Utils.hex(x)} = #{Utils.hex(@memory.read(x))}"
        x
      when :indexed_indirect then
        taddr = @memory.read(@pc)
        addr1 = (taddr &+ @x).to_u16
        addr = ((addr1 & 0xFF00_u16) | (addr1.to_u8 &+ 1_u8))
        x = ((@memory.read(addr).to_u16 << 8) | @memory.read(addr1).to_u16)
        #@debug_addition = "($#{Utils.hex(taddr)},X) @ #{Utils.hex(addr1.to_u8)} = #{Utils.hex(x)} = #{Utils.hex(@memory.read(x))}"
        x
      when :indirect_indexed then
        taddr = @memory.read(@pc)
        addr1 = taddr.to_u16
        addr = ((addr1 & 0xFF00_u16) | (addr1.to_u8 &+ 1_u8))
        x1 = ((@memory.read(addr).to_u16 << 8) | @memory.read(addr1).to_u16)
        x = ((@memory.read(addr).to_u16 << 8) | @memory.read(addr1).to_u16) &+ @y
        if (x1 & 0xFF00) != (x & 0xFF00)
          @additional_cycles += 1
          # Dummy-Read
          @memory.read(x &- 0x0100)
        end
        #@debug_addition = "($#{Utils.hex(taddr)}),Y = #{Utils.hex(x1)} @ #{Utils.hex(x)} = #{Utils.hex(@memory.read(x))}"
        x
      else
        raise "Unknown addressing mode #{op[3]}"
      end
    end

    private def print_debug(instruction, op, addr)
      args =
        if op[2] == 2
          virt_pc = @pc - (op[2])
          addr1 = Utils.hex(@memory.read(virt_pc))
          addr2 = Utils.hex(@memory.read(virt_pc+1))
          [addr1, addr2].join(" ")
        elsif op[2] == 1
          virt_pc = @pc - (op[2])
          addr1 = Utils.hex(@memory.read(virt_pc))
          "#{addr1}   "
        else
          "     "
        end

      line = "#{Utils.hex(@pc - (op[2] + 1))}  #{Utils.hex(instruction)} " \
        "#{args}  #{op[1]} "##{@debug_addition.ljust(27, ' ')}"# A:#{Utils.hex(@a)} X:#{Utils.hex(@x)} " \
        #"Y:#{Utils.hex(@y)} P:#{Utils.hex(@flags.value)} SP:#{Utils.hex(@sp)}"

      7.times do |i|
        @debug_infos[i] = @debug_infos[i + 1]
      end
      @debug_infos[7] = line
      # @debug_idx = (@debug_idx + 1) % 8
    end
  end
end
