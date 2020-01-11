require "debug"
require "./crystal_nes/**"

module CrystalNes
  VERSION = "0.1.0"

  def self.start
    console = Console.new
    console.insert_rom_file(ARGV.join(" "))
    Gui.new(console).main_loop
  end
end
