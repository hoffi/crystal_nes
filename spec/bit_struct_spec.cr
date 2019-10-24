require "./spec_helper"
require "../src/bit_struct"

struct TestStruct < BitStruct(UInt16)
  bf coarse_x : UInt8, 5
  bf coarse_y : UInt8, 5
  bf nametable_x : UInt8, 1
  bf nametable_y : UInt8, 1
  bf fine_y : UInt8, 3
  bf unused : UInt8, 1
end

# TODO: More Tests
describe BitStruct do
  it "works" do
    var = TestStruct.new(0b000000000000110)
    var.coarse_x.should eq 0
    var.coarse_y.should eq 0
    var.nametable_x.should eq 0
    var.nametable_y.should eq 0
    var.fine_y.should eq 3
    var.unused.should eq 0
    var.value.should eq 6
    var.value = 0b000000000000011
    var.fine_y.should eq 1
    var.unused.should eq 1
    var.value.should eq 3
  end

  it "does not overflow" do
    var = TestStruct.new(0)
    var.nametable_x = 5
    var.nametable_x.should eq 1
    var.coarse_x = 32
    var.coarse_x.should eq 0
    var.fine_y = 5
    var.fine_y.should eq 5
    var.fine_y = 9
    var.fine_y.should eq 1
    var.value.should eq 34
    var.value = 255_u16
    var.value.should eq 255
  end
end
