class Game
  attr_reader :game, :ownerships

  def initialize(game, ownerships)
    @game = game
    @ownerships = ownerships
  end

  def id
    @game.id
  end

  %i(prev_own own).each do |sym|
    class_eval <<~EOF
      def #{sym}ed?
        #{sym}ers.any?
      end

      def #{sym}ed_by?(user)
        #{sym}ers.any? { |u| u == user }
      end

      def #{sym}ers
        @ownerships.select(&:own).map(&:#{sym}er).uniq
      end
    EOF
  end

  def want_to_play?
    want_to_players.any?
  end

  def want_to_play_by?(user)
    want_to_players.any? { |u| u == user }
  end

  def want_to_players
    (likers + @ownerships.select(&:wanttoplay).map(&:owner)).uniq
  end

  {like: ">= 7", love: ">= 8", dislike: "<= 6", hate: "<= 5"}.each do |sym, clause|
    class_eval <<~EOF
      def #{sym}rs
        player_rating_summary.select { |_, v| v #{clause} }.keys
      end

      def #{sym}d_by_group?
        num_#{sym}rs > 1
      end

      def #{sym}d_by_someone?
        num_#{sym}rs >= 1
      end

      def num_#{sym}rs
        #{sym}rs.size
      end
    EOF
  end

  def raters
    player_rating_summary.keys.uniq
  end

  def num_raters
    raters.size
  end

  def rated?
    num_raters > 0
  end

  def href
    "https://boardgamegeek.com/thing/#{id}"
  end

  def median_player_rating
    return -1 if player_ratings.none?

    ratings = player_ratings
    if ratings.size % 2 == 0
      ((ratings[ratings.size/2-1] + ratings[ratings.size/2]) / 2.0).round(1)
    else
      (ratings[ratings.size/2.0]*1.0).round(1)
    end
  end

  def avg_player_rating
    (player_ratings.sum / (player_ratings.size * 1.0)).round(1)
  end

  def player_ratings
    @ownerships.map(&:rating).compact.map(&:to_f).reject { |x| x == 0 }.sort
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

  def mechanics
    @game.mechanics.map(&:downcase).map { |m| m.sub(/\s*\/\s*/, " and ") }
  end

  %i(
    best_with
    recommended_with
    dislikers
    haters
    likers
    lovers
    mechanics
    owners
    raters
    want_to_players
  ).each do |sym|
    class_eval <<~EOF
      def #{sym}?(v)
        if v.respond_to?(:each)
          v.any? { |v2| #{sym}.include?(v2) }
        else
          #{sym}.include?(v)
        end
      end
    EOF
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
    rank = @game.statistics[0].ranks.find { |rank| rank.friendlyname == "Board Game Rank" }.value.to_i
    (rank == 0) ? 1000 : rank
  end

  def solo_only?
    best_with == [1]
  end

  def two_player_only?
    best_with == [2] && recommended_with.none? { |x| x >= 3 }
  end
end
