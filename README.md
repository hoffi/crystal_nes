# CrystalNES

A NES Emulator written in [Crystal](https://crystal-lang.org)

## Current status

![Status Screenshot](https://raw.githubusercontent.com/hoffi/crystal_nes/master/screenshot.png)

- [x] Basic CPU (only official opcodes)
- [ ] Complete CPU (with unofficial opcodes and tests)
- [x] Controller
- [ ] PPU
  - [ ] Basic background rendering (works but colors are wrong)
  - [ ] Sprite rendering
  - [ ] Correct timings
- [ ] APU
- [ ] Mappers
  - [x] [Mapper 0 / NROM](http://wiki.nesdev.com/w/index.php/NROM)
  - [ ] [Mapper 1 / SxROM](http://wiki.nesdev.com/w/index.php/MMC1)
  - [ ] [Mapper 2 / UxROM](http://wiki.nesdev.com/w/index.php/UxROM)
  - [ ] [Mapper 3 / CNROM](http://wiki.nesdev.com/w/index.php/INES_Mapper_003)
- [ ] GUI
  - [x] PPU output
  - [x] CPU Flags and Register values
  - [ ] Disassembler
  - [ ] Debugger

## Usage

[raylib](https://www.raylib.com) needs to be installed on the system.

```sh
crystal run main.cr -- path/to/rom.nes
```

## References

[Nesdev Wiki](http://wiki.nesdev.com/w/index.php/NES_reference_guide)

[6502 Reference](http://obelisk.me.uk/6502/reference.html)
