require "../spec_helper"

describe CrystalNes::Controller do
  context "#read" do
    it "reads one bit at a time and shifts one left" do
      controller = CrystalNes::Controller.new(0b10101010_u8)

      # Read 8 times for both controllers ports
      [0, 1].each do |port|
        controller.read(port).should eq 1
        controller.read(port).should eq 0
        controller.read(port).should eq 1
        controller.read(port).should eq 0
        controller.read(port).should eq 1
        controller.read(port).should eq 0
        controller.read(port).should eq 1
        controller.read(port).should eq 0

        # All values has been shifted out, only zeroes are returned now
        controller.read(port).should eq 0
        controller.read(port).should eq 0
        controller.read(port).should eq 0
      end
    end

    it "does not shift on debug reads" do
      controller = CrystalNes::Controller.new(0b10101010_u8)

      [0, 1].each do |port|
        controller.read(port, true).should eq 1
        controller.read(port, true).should eq 1
        controller.read(port, true).should eq 1
      end
    end
  end

  context "#write" do
    it "does nothing when a 0 is written" do
      controller = CrystalNes::Controller.new(5_u8)
      controller.state = Bytes[2, 2]
      controller.latched_state.should eq Bytes[5, 5]
      controller.write(0, 0)
      controller.latched_state.should eq Bytes[5, 5]
      controller.state.should eq Bytes[2, 2]
    end

    it "updates the latched state with the current state values when a 1 is " \
       "written" do
      controller = CrystalNes::Controller.new(5_u8)
      controller.state = Bytes[2, 2]
      controller.latched_state.should eq Bytes[5, 5]
      controller.write(0, 1)
      controller.latched_state.should eq Bytes[2, 2]
    end
  end

  context "#reset!" do
    it "resets the internal state" do
      controller = CrystalNes::Controller.new(5_u8)
      controller.state.should eq Bytes[5, 5]
      controller.latched_state.should eq Bytes[5, 5]
      controller.reset!
      controller.state.should eq Bytes[0, 0]
      controller.latched_state.should eq Bytes[5, 5]
    end
  end

  context "#press_button!" do
    it "writes the pressed button into the state" do
      controller = CrystalNes::Controller.new
      controller.state.should eq Bytes[0, 0]
      controller.press_button! 0, CrystalNes::Controller::Button::A
      controller.press_button! 1, CrystalNes::Controller::Button::Start
      controller.state.should eq Bytes[0x80, 0x10]
      controller.latched_state.should eq Bytes[0, 0]
    end

    it "multiple pressed buttons are or'ed" do
      controller = CrystalNes::Controller.new
      controller.state[0].should eq 0_u8
      controller.press_button! 0, CrystalNes::Controller::Button::A
      controller.press_button! 0, CrystalNes::Controller::Button::B
      controller.state[0].should eq 0xC0_u8
      controller.latched_state[0].should eq 0_u8
    end
  end
end
