#  vim: set fileencoding=utf-8 filetype=ruby ts=2 : 

module SwfRuby
  # Swf構造をダンプするクラス.
  class SwfDumper
    attr_reader :swf
    attr_reader :header
    attr_reader :tags
    attr_reader :tags_addresses

    # 初期化.
    def initialize
      @swf = nil
      @header = nil
      @tags = nil
      @tags_addresses = nil
    end

    # ファイルをバイナリモードで読み込み.
    # 1.9環境の場合はエンコーディング指定.
    def open(file)
      f = File.open(file, "rb").read
      f.force_encoding("ASCII-8BIT") if f.respond_to? :force_encoding
      dump(f)
    end

    # ダンプして構造をインスタンス変数に格納.
    def dump(swf)
      @swf = swf
      @header = Swf::Header.new(@swf)
      @tags = []
      @tags_addresses = []
      tags_length = 0
      while @header.length + tags_length < @header.file_length
        addr = @header.length + tags_length
        @tags_addresses << addr
        tag = Swf::Tag.new(@swf[addr..-1])
        tags_length += tag.length
        @tags << tag
      end
      self
    end

    def show
      self.tags.each_with_index do |tag, i|
        out_print "#{SwfRuby::Swf::TAG_TYPE[tag.code]}, offset: #{self.tags_addresses[i]}, length: #{tag.length}\n"
        if tag.code == 39
          # DefineSprite
          sd = SwfRuby::SpriteDumper.new
          sd.dump(tag)
          out_print "  Sprite ID: #{sd.sprite_id}, Frame Count: #{sd.frame_count}\n"
          sd.tags.each_with_index do |tag2, k|
            out_print "    #{SwfRuby::Swf::TAG_TYPE[tag2.code]}, offset: #{sd.tags_addresses[k]}, length: #{tag2.length}\n"
            if tag2.code == 12
              # DoAction
              dad = SwfRuby::DoActionDumper.new
              dad.dump(self.swf[self.tags_addresses[i] + sd.tags_addresses[k], tag2.length])
              dad.actions.each_with_index do |ar, l|
                out_print "      #{SwfRuby::Swf::ACTION_RECORDS[ar.code]}, offset: #{dad.actions_addresses[l]}, length: #{ar.length}\n"
                if ar.code == 150
                  # ActionPush
                  ap = SwfRuby::Swf::ActionPush.new(ar)
                  out_print "       type: #{ap.data_type}, offset: #{dad.actions_addresses[l]}, data: #{ap.data}\n"
                end
              end
            end
          end
        end
        if tag.code == 12
          # DoAction
          dad = SwfRuby::DoActionDumper.new
          dad.dump(self.swf[self.tags_addresses[i], tag.length])
          dad.actions.each_with_index do |ar, j|
            out_print "  #{SwfRuby::Swf::ACTION_RECORDS[ar.code]}, offset: #{dad.actions_addresses[j]}, length: #{ar.length}\n"
            if ar.code == 150
              # ActionPush
              ap = SwfRuby::Swf::ActionPush.new(ar)
              out_print "    type: #{ap.data_type}, offset: #{dad.actions_addresses[j]}, data: #{ap.data}\n"
            end
          end
        end
      end

      out_print "\n" 
    end

    private
    # UTF-8で出力
    def out_print(str) 
      str = str.force_encoding("Windows-31J").encode("UTF-8") if str.respond_to? :force_encoding
      print str 
    end
  end
end
