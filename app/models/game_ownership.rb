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
