require "./src/crystal_nes"

filename = ARGV[0]
ines = CrystalNes::INes.new filename
cartridge = ines.parse
puts cartridge.infos.inspect

console = CrystalNes::Console.new(cartridge)

begin
  gui = CrystalNes::GUI.new(console)
  gui.main_loop
  gui.close
ensure
  console.dump_memory
end
