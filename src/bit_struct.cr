# TODO: WIP

@[Packed]
abstract struct BitStruct(T)
  macro inherited
    FIELDS = {} of Nil => Nil

    macro finished
      process_fields
    end
  end

  macro bf(name, bitsize)
    {% FIELDS[name.var] = {name.type, bitsize} %}
    property {{name.var}} : {{name.type}} = {{name.type}}.new(0)
  end

  macro process_fields
    def initialize(val : T)
      {% for name, infos in FIELDS %}
        @{{name.id}} |= val >> (sizeof(T) * 8) - {{infos[1]}}
        val <<= {{infos[1]}}
      {% end %}
    end

    {% for name, infos in FIELDS %}
      def {{name.id}}=(val : {{infos[0]}})
        bits = (((1 << (0 - 1)) - 1) ^ ((1 << {{infos[1]}}) - 1)).abs - 1
        @{{name.id}} = val & bits
      end
    {% end %}

    def value
      result = T.new(0)
      {% for name, infos in FIELDS %}
        result <<= {{infos[1]}}
        result |= T.new(@{{name.id}})
      {% end %}
      result
    end

    def value=(val : T)
      {% for name, infos in FIELDS %}
        @{{name.id}} = 0
        @{{name.id}} |= val >> (sizeof(T) * 8) - {{infos[1]}}
        val <<= {{infos[1]}}
      {% end %}
    end
  end
end
