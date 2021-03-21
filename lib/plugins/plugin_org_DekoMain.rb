module Plugins
  class Plugin_org_DekoMain
    def initialize(content, params, database, &block)
      @content = content
      @params = params
      @database = database
      @block = block
      download
    end

    def dl(name)
      @block.call :dl_img, "pictures", name
    end

    def num(regex)
      @content.match(regex)[1].to_i
    end

    def padding(i, l=4)
      i.to_s.rjust(l, "0")
    end

    def download
      gstate = {}
      for m in @content.scan(/\.def_gstate_(?<key>[^\s=]+)\s*=\s*(?<value>\d+)/)
        key, vstr = *m
        gstate[key.downcase.delete("_")] = vstr.to_i
      end
      b_max_def = @content.scan(/^\s*(var|let|const)\s*b_max\s*=\s*(?<value>\d+)/)[0][0].to_i
      b_max_list = {}
      b_max_list.default = b_max_def
      for m in @content.scan(/if\(this\.CheckGirlState_[^{]+{\s*[^}]*b_max\s*=\s*[^}]+/m)
        rulem = m.scan(/if\s*\((?<rule>.*)\s*\)\s*{/)
        rules = rulem[0][0].split("||").map { |r| r.scan(/this\.CheckGirlState_([^(]+)\(/)[0][0].downcase.delete("_") }
        dat = {}
        for pairm in m.scan(/^\s*(?<key>[^\s=]+)\s*=[\s(]*(?:(?<add>[^\s+]+)\s*(?:\+|-)\s*)?(?<value>[\d\s+-]+)\)?;?/)
          key, add, vstr = *pairm
          v = 0
          vs = vstr ? vstr.scan(/(\d+|\+|-)/) : []
          unless vs.empty?
            v = vs.shift[0].to_i
            until vs.empty?
              op = vs.shift[0]
              addv = vs.shift[0].to_i
              v = v.send op, addv
            end
          end
          dat[key] = (add and dat[add]) ? dat[add] + v : v
        end
        for rule in rules
          b_max_list[gstate[rule]] = dat["b_max"]
        end
      end

      for i in 0...num(/this\._ImgIconList\s*=\s*new Array\((\d+)\);?/)
        dl "ICON_#{padding i}"
      end

      for state in 0..56 # Ln.1874~1879 range => 0~56
        statestr = padding state, 3
        for i in 0...b_max_list[state]
          istr = padding i
          dl "BODY#{statestr}_#{istr}"
          dl "BODY#{statestr}_b#{istr}"
        end
      end
      for i in 0...num(/this\._ImgFootList\s*=\s*new Array\((\d+)\);?/)
        dl "FOOT_#{padding i}"
      end
      for i in 0...num(/this\._ImgArmList\s*=\s*new Array\((\d+)\);?/)
        dl "ARM_#{padding i}"
      end
      dl "BG_BLACK"
      dl "BG_ROOM_0000"
      for i in %w{FOOT BODY ARM ICON BG _PIC}
        dl "#{i}_CLEAR"
      end
      dl "_PIC_None"
      for i in @content.scan /this\.LoadPicList\(\d+\s*,\s*\d+\s*,\s*"([^"]+)"\);?/
        dl i[0]
      end
    end

    def self.match(name, *args, &block)
      return self.new *args, &block if name == "_org_DekoMain"
    end
  end

  PLUGIN_LIST.push Plugin_org_DekoMain
end
