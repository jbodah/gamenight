require "net/http"
require "nokogiri"
require "ostruct"

module AllGames
  class << self
    def load_collections
      Marshal.load(File.read('collections.out'))
    end

    def load_games
      Marshal.load(File.read('games.out'))
    end

    def call
      users = %w(hiimjosh iadena yourwhiteshadow Falcifer666 adamabsurd)

      collections = load_collections
      collections = collections.map do |owner, xml|
        collection = Bgg::Collection.new(owner)
        doc = Nokogiri::XML(xml) do |c|
          c.options = Nokogiri::XML::ParseOptions::NOBLANKS
        end
        collection.games = Bgg::Parser.parse(doc.children[0])
        collection
      end

      ownerships_by_game_id = {}
      collections.each do |c|
        c.games.each do |g|
          ownerships_by_game_id[g.objectid] ||= []
          ownerships_by_game_id[g.objectid] << GameOwnership.new(g, c)
        end
      end

      loaded_games = load_games
      games = []
      loaded_games.each do |xml|
        doc = Nokogiri::XML(xml) do |c|
          c.options = Nokogiri::XML::ParseOptions::NOBLANKS
        end
        doc.children[0].children.map do |game|
          game2 = Bgg::Parser.parse(game)
          # Owner not attending
          next if ownerships_by_game_id[game2.id].nil?
          games << Game.new(game2, ownerships_by_game_id.fetch(game2.id))
        end
      end
      games.reject! { |g| g.type == "boardgameexpansion" }

      GameProxy.new(games)
    end
  end
end
