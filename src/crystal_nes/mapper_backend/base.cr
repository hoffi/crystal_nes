module CrystalNes
  module MapperBackend
    abstract class Base
      abstract def read(address, debug = false)
      abstract def write(address, data)
    end
  end
end
