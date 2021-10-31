#! /usr/bin/env ruby
require "bundler/setup"
require "net/http"
require "nokogiri"
require "ostruct"
require "logger"
require "yaml"

$stderr.sync = true

$logger = Logger.new($stderr)
$logger.level = Logger::DEBUG

class Object
  def in?(enum)
    enum.include? self
  end

  def not_in?(enum)
    !in?(enum)
  end
end

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

class GameOwnership
  attr_reader :game, :collection

  def initialize(game, collection)
    @game = game
    @collection = collection
  end

  def owner
    @collection.owner
  end

  def rating
    @game.stats.rating.value
  end

  def prevowned
    @game.status.prevowned == "1"
  end

  def own
    @game.status.own == "1"
  end

  def wanttoplay
    @game.status.wanttoplay == "1"
  end

  def method_missing(sym)
    @game.send(sym)
  end
end

class Game
  attr_reader :game, :ownerships

  def initialize(game, ownerships)
    @game = game
    @ownerships = ownerships
  end

  def id
    @game.id
  end

  def prev_owned?
    prev_owners.any?
  end

  def owned?
    owners.any?
  end

  def want_to_play?
    want_to_players.any?
  end

  def liked_by_group?
    likers.count > 1
  end

  def liked_by_someone?
    likers.any?
  end

  def likers
    player_rating_summary.select { |_, v| v >= 7 }.keys
  end

  def loved_by_group?
    lovers.count > 1
  end

  def loved_by_someone?
    lovers.any?
  end

  def lovers
    player_rating_summary.select { |_, v| v >= 8 }.keys
  end

  def disliked_by_someone?
    dislikers.any?
  end

  def dislikers
    player_rating_summary.select { |_, v| v <= 6 }.keys
  end

  def hated_by_someone?
    haters.any?
  end

  def haters
    player_rating_summary.select { |_, v| v <= 5 }.keys
  end

  def raters
    player_rating_summary.keys.uniq
  end

  def prev_owners
    @ownerships.select(&:prevowned).map(&:owner).uniq
  end

  def owners
    @ownerships.select(&:own).map(&:owner).uniq
  end

  def want_to_players
    @ownerships.select(&:wanttoplay).map(&:owner).uniq
  end

  def player_ratings
    @ownerships.map(&:rating).compact.map(&:to_i).reject { |x| x == 0 }
  end

  def player_rating_summary
    @ownerships.map { |o| [o.owner, o.rating.to_i] }.to_h.reject { |_, v| v == 0 }
  end

  def unique_owners
    @ownerships.map(&:owner).uniq
  end

  def name
    @game.primary_name.value
  end

  %i(minplayers maxplayers minplaytime maxplaytime playingtime).each do |stat|
    class_eval <<~EOF
      def #{stat}
        @game.#{stat}.value.to_i
      end
    EOF
  end

  def suggested_numplayers
    h = @game.suggested_numplayers
    h.delete_if { |k, _| k.end_with? "+" }
    h.transform_keys(&:to_i)
  end

  def best_with?(n)
    best_with.include?(n)
  end

  def recommended_with?(n)
    recommended_with.include? n
  end

  def best_with
    suggested_numplayers.select do |k, v|
      v[:best] > v[:recommended] + v[:not_recommended]
    end.keys
  end

  def recommended_with
    suggested_numplayers.reject do |k, v|
      v[:not_recommended] > 0.8 * (v[:best] + v[:recommended])
    end.keys
  end

  # def has_mechanic?(pattern)
  #   @game.mechanics.map(&:downcase).grep(pattern).any?
  # end

  def filler?
    playingtime <= 45 && weight < 2.5
  end

  def meaty_filler?
    playingtime <= 60 && weight >= 2.5
  end

  # TODO: @jbodah 2021-07-13: user rating
  def weight
    @game.statistics[0].averageweight.value.to_f
  end

  def user_rating
    @game.statistics[0].average.value.to_f
  end

  def type
    @game.type
  end

  def bgg_rank
    @game.statistics[0].ranks.find { |rank| rank.friendlyname == "Board Game Rank" }.value.to_i
  end
end

class GameProxy
  include Enumerable

  attr_reader :games

  def initialize(games)
    @games = games
  end

  def each(&blk)
    return to_enum unless block_given?
    @games.each(&blk)
  end

  def not(sym, *args)
    GameProxy.new(@games.reject { |g| g.send "#{sym}?", *args })
  end

  def method_missing(sym, *args, &blk)
    GameProxy.new(@games.select { |g| g.send "#{sym}?", *args })
  end
end

def retry_errors
  backoff = Enumerator.new do |y|
    y.yield 2
    n = 4
    loop do
      y.yield n
      n = [n**2, 20].min
    end
  end

  resp = nil
  loop do
    $logger.info "Making request"
    resp = yield
    if /Rate limit exceeded/.match?(resp) || /Please try again later/.match?(resp)
      boff = backoff.next
      $logger.info "Rate limited; sleeping for #{boff}"
      sleep boff
    else
      break
    end
  end
  resp
end

def download_collections(users)
  collections = users.reduce({}) do |acc, user|
    collection = retry_errors do
      Net::HTTP.get(URI("https://boardgamegeek.com/xmlapi2/collection?username=#{user}&stats=1"))
    end
    acc[user] = collection
    acc
  end
  File.open('collections.out', 'w') do |f|
    f.write Marshal.dump(collections)
  end
end

def download_games(collections)
  objectids = collections.flat_map { |c| c.games.map(&:objectid) }.uniq
  games = objectids.each_slice(30).map do |slice|
    retry_errors do
      Net::HTTP.get(URI("https://boardgamegeek.com/xmlapi2/thing?id=#{slice.join(',')}&stats=1"))
    end
  end
  File.open('games.out', 'w') do |f|
    f.write Marshal.dump(games)
  end
end

def load_collections
  Marshal.load(File.read('collections.out'))
end

def load_games
  Marshal.load(File.read('games.out'))
end

users = YAML.load_file('config/bgg.yaml').fetch("users")
download_collections(users)
collections = load_collections
collections = collections.map do |owner, xml|
  collection = Bgg::Collection.new(owner)
  doc = Nokogiri::XML(xml) do |c|
    c.options = Nokogiri::XML::ParseOptions::NOBLANKS
  end
  collection.games = Bgg::Parser.parse(doc.children[0])
  collection
end
download_games(collections)
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
# games.reject! { |g| g.type == "boardgameexpansion" }

filter = GameProxy.new(games).owned
File.write('filter.out', Marshal.dump(filter))
