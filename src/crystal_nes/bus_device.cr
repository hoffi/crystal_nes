module CrystalNes
  abstract class BusDevice
    abstract def read(address, debug = false)
    abstract def write(address, data)
  end
end
