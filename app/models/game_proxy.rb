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

  def where(&blk)
    GameProxy.new(@games.select(&blk))
  end

  def not(sym, *args)
    GameProxy.new(@games.reject { |g| g.send "#{sym}?", *args })
  end

  def respond_to_missing?(sym, incl_private=false)
    @games[0].respond_to?("#{sym}?", incl_private)
  end

  def method_missing(sym, *args, &blk)
    GameProxy.new(@games.select { |g| g.send "#{sym}?", *args })
  end
end
