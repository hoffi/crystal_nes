require "./palettes/*"

module CrystalNes
  class Palette
    def initialize
      @palette = Palettes::Palette2C02.new
    end

    delegate fetch, to: @palette
  end
end
