module CrystalNes
  class Mapper
    def initialize
      @mapper_backend = uninitialized MapperBackend::Base
    end

    delegate read, write, mirror_mode, to: @mapper_backend

    def prepare_mapper(rom_data)
      @mapper_backend =
        case rom_data.mapper_number
        when 0 then MapperBackend::Nrom.new(rom_data)
        # TODO: Implement more mappers...
        else raise "Unimplemented mapper #{rom_data.mapper_number}!"
        end
    end
  end
end
