module Bgg
  class Collection
    attr_accessor :games
    attr_reader :owner

    def initialize(owner)
      @owner = owner
    end
  end

  class BGGObject
    include Enumerable

    def initialize(ostruct)
      @ostruct = ostruct
    end

    def __type
      @ostruct.__type
    end

    def each(&blk)
      return to_enum unless block_given?
      @ostruct.children.each(&blk)
    end

    def [](idx)
      @ostruct.children[idx]
    end

    def table
      @ostruct.instance_eval { @table }
    end

    def primary_name
      find { |c| c.__type == "name" && c.type == "primary" }
    end

    def best
      find { |c| c.__type == "result" && c.value == "Best" }
    end

    def recommended
      find { |c| c.__type == "result" && c.value == "Recommended" }
    end

    def not_recommended
      find { |c| c.__type == "result" && c.value == "Not Recommended" }
    end

    def categories
      select { |c| c.type == "boardgamecategory" }.map(&:value)
    end

    def mechanics
      select { |c| c.type == "boardgamemechanic" }.map(&:value)
    end

    # suggested_playerage language_dependence
    %i(suggested_numplayers).each do |poll|
      class_eval <<~EOF
        def #{poll}
          poll = find { |c| c.__type == "poll" && c.name == "#{poll}" }
          poll.map do |r|
            spec = {
              best: r.best&.numvotes.to_i,
              recommended: r.recommended&.numvotes.to_i,
              not_recommended: r.not_recommended&.numvotes.to_i,
            }
            [r.numplayers, spec]
          end.to_h
        end
      EOF
    end

    def method_missing(sym, *args, &blk)
      return @ostruct[sym] if @ostruct[sym]
      find { |c| c.__type.to_sym == sym }
    end
  end

  class Parser
    class << self
      def parse(doc)
        type = doc.name
        obj = OpenStruct.new(__type: type, **doc.attributes.map { |_, v| [v.name, v.value] }.to_h)
        obj.children = doc.children.map { |child| parse(child) }
        obj.text = doc.text
        BGGObject.new(obj)
      end
    end
  end
end
