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

  def prev_owned_by?(user)
    prev_owners.any? { |u| u == user }
  end

  def owned?
    owners.any?
  end

  def owned_by?(user)
    owners.any? { |u| u == user }
  end

  def want_to_play?
    want_to_players.any?
  end

  def want_to_play_by?(user)
    want_to_players.any? { |u| u == user }
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

  def mean_player_rating
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
    if n.respond_to?(:each)
      n.any? { |n2| best_with.include?(n2) }
    else
      best_with.include?(n)
    end
  end

  def recommended_with?(n)
    if n.respond_to?(:each)
      n.any? { |n2| recommended_with.include?(n2) }
    else
      recommended_with.include?(n)
    end
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
    rank = @game.statistics[0].ranks.find { |rank| rank.friendlyname == "Board Game Rank" }.value.to_i
    (rank == 0) ? 1000 : rank
  end

  def solo_only?
    recommended_with == [1]
  end
end
