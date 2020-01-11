require "../../spec_helper"

class FakeMapper < CrystalNes::Mapper
  def initialize(content)
    @mapper_backend = uninitialized CrystalNes::MapperBackend::Base
    @memory = Bytes.new(0x8000) { 0_u8 }
    content.size.times { |i| @memory[i.to_u8] = content[i].to_u8 }
  end

  def read(address, _dbg); @memory[address - 0x8000]; end
  def write(address, data); @memory[address - 0x8000] = data; end
end

class FakeBus < CrystalNes::Bus
  def initialize(content)
    mapper = FakeMapper.new(content)
    super(mapper, CrystalNes::Ppu.new(mapper), CrystalNes::Controller.new)
  end
end

class FakeCpu < CrystalNes::Cpu
  getter pc, cycles
  setter pc, a, x, y

  def reset_vector
    0x8000_u16
  end
end

describe CrystalNes::Cpu::AddressingModes do
  context "#load_immediate" do
    it "loads the next byte and increments the program counter" do
      _, cpu = build_fake_cpu(5, 10)

      cpu.pc.should eq 0x8000
      cpu.load_immediate.should eq 5_u8
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 0
    end
  end

  context "#load_absolute" do
    it "loads the next two bytes and increments the program counter twice" do
      _, cpu = build_fake_cpu(0x00, 0xC0)

      cpu.pc.should eq 0x8000
      cpu.load_absolute.should eq 0xC000_u16
      cpu.pc.should eq 0x8002
      cpu.cycles.should eq 2
    end
  end

  context "#load_absolute_x" do
    it "loads the next two bytes and increments the program counter twice" do
      _, cpu = build_fake_cpu(0x00, 0xC0)

      cpu.pc.should eq 0x8000
      cpu.load_absolute_x.should eq 0xC000_u16
      cpu.pc.should eq 0x8002
      cpu.cycles.should eq 2
    end

    it "adds the contents of the X register to the address" do
      _, cpu = build_fake_cpu(0x00, 0xC0)
      cpu.x = 2_u8

      cpu.load_absolute_x.should eq 0xC002_u16
    end

    it "takes one extra cycle when a page is crossed" do
      _, cpu = build_fake_cpu(0x01, 0xC0)
      cpu.x = 0xFF_u8

      cpu.load_absolute_x.should eq 0xC100_u16
      cpu.cycles.should eq 3
    end
  end

  context "#load_absolute_y" do
    it "loads the next two bytes and increments the program counter twice" do
      _, cpu = build_fake_cpu(0x00, 0xC0)

      cpu.pc.should eq 0x8000
      cpu.load_absolute_y.should eq 0xC000_u16
      cpu.pc.should eq 0x8002
      cpu.cycles.should eq 2
    end

    it "adds the contents of the Y register to the address" do
      _, cpu = build_fake_cpu(0x00, 0xC0)
      cpu.y = 2_u8

      cpu.load_absolute_y.should eq 0xC002_u16
    end

    it "takes one extra cycle when a page is crossed" do
      _, cpu = build_fake_cpu(0x01, 0xC0)
      cpu.y = 0xFF_u8

      cpu.load_absolute_y.should eq 0xC100_u16
      cpu.cycles.should eq 3
    end
  end

  context "#load_zero_page" do
    it "loads the next byte and increments the program counter" do
      _, cpu = build_fake_cpu(0x08, 0xA0)

      cpu.pc.should eq 0x8000
      cpu.load_zero_page.should eq 0x0008_u16
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 1
    end
  end

  context "#load_zero_page_x" do
    it "loads the next byte and increments the program counter twice" do
      _, cpu = build_fake_cpu(0x08, 0xA0)

      cpu.pc.should eq 0x8000
      cpu.load_zero_page_x.should eq 0x0008_u16
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 1
    end

    it "adds the contents of the X register to the address" do
      _, cpu = build_fake_cpu(0x08)
      cpu.x = 2_u8

      cpu.load_zero_page_x.should eq 0x000A_u16
    end

    it "does not cross pages" do
      _, cpu = build_fake_cpu(0x80)
      cpu.x = 0xFF_u8

      cpu.load_zero_page_x.should eq 0x007F_u16
    end
  end

  context "#load_zero_page_y" do
    it "loads the next byte and increments the program counter twice" do
      _, cpu = build_fake_cpu(0x08, 0xA0)

      cpu.pc.should eq 0x8000
      cpu.load_zero_page_y.should eq 0x0008_u16
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 1
    end

    it "adds the contents of the Y register to the address" do
      _, cpu = build_fake_cpu(0x08)
      cpu.y = 2_u8

      cpu.load_zero_page_y.should eq 0x000A_u16
    end

    it "does not cross pages" do
      _, cpu = build_fake_cpu(0x80)
      cpu.y = 0xFF_u8

      cpu.load_zero_page_y.should eq 0x007F_u16
    end
  end

  context "#load_relative" do
    it "loads the next byte and adds it to the current program counter" do
      _, cpu = build_fake_cpu(0x08, 0xA0)

      cpu.pc.should eq 0x8000
      cpu.load_relative.should eq 0x8009_u16
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 0
    end

    it "can subtract" do
      _, cpu = build_fake_cpu(0, 0xFE)
      cpu.pc = 0x8001_u16
      cpu.load_relative.should eq 0x8000_u16
    end
  end

  context "#load_indirect" do
    it "loads two bytes from the specified memory location" do
      _, cpu = build_fake_cpu(0x03, 0x80, 0, 0x01, 0xD0)

      cpu.pc.should eq 0x8000
      cpu.load_indirect.should eq 0xD001_u16
      cpu.pc.should eq 0x8002
      cpu.cycles.should eq 4
    end
  end

  context "#load_indirect_x" do
    it "loads two bytes from the specified zero page location" do
      bus, cpu = build_fake_cpu(0x02)
      bus.write(2, 0x01_u8)
      bus.write(3, 0xAB_u8)

      cpu.pc.should eq 0x8000
      cpu.load_indirect_x.should eq 0xAB01_u16
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 4
    end

    it "adds the contents of the X register to the zero page address" do
      bus, cpu = build_fake_cpu(0x02)
      cpu.x = 2_u8
      bus.write(4, 0x01_u8)
      bus.write(5, 0xAB_u8)

      cpu.load_indirect_x.should eq 0xAB01_u16
    end
  end

  context "#load_indirect_y" do
    it "loads two bytes from the specified zero page location" do
      bus, cpu = build_fake_cpu(0x02)
      bus.write(2, 0x01_u8)
      bus.write(3, 0xAB_u8)

      cpu.pc.should eq 0x8000
      cpu.load_indirect_y.should eq 0xAB01_u16
      cpu.pc.should eq 0x8001
      cpu.cycles.should eq 3
    end

    it "adds the contents of the Y register to the contents of the zero page" do
      bus, cpu = build_fake_cpu(0x02)
      cpu.y = 2_u8
      bus.write(2, 0x01_u8)
      bus.write(3, 0xAB_u8)

      cpu.load_indirect_y.should eq 0xAB03_u16
    end

    it "takes an extra cycle when a page would be crossed but does not " \
       "actually cross it" do
      bus, cpu = build_fake_cpu(0x02)
      cpu.y = 2_u8
      bus.write(2, 0xFF_u8)
      bus.write(3, 0xAB_u8)

      cpu.load_indirect_y.should eq 0xAC01_u16
      cpu.cycles.should eq 4
    end
  end
end

private def build_fake_cpu(*prg_content)
  bus = FakeBus.new(prg_content)
  cpu = FakeCpu.new(bus)
  cpu.power_up!
  {bus, cpu}
end
