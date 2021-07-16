class GameController < ApplicationController
  SIMPLE_PARAMS = %w(
    avg_player_rating
    bgg_rank
    id
    maxplayers
    maxplaytime
    median_player_rating
    minplayers
    minplaytime
    name
    num_dislikers
    num_haters
    num_likers
    num_lovers
    num_raters
    playingtime
    user_rating
    weight
  )

  COLLECTION_PARAMS = %w(
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
  )

  before_action do
    @simple_params = SIMPLE_PARAMS
    @collection_params = COLLECTION_PARAMS
    @games = $proxy.owned.not(:solo_only).not(:two_player_only)
    @total = @games.count
    @mechanics_ranking = mechanics_ranking
    @mechanics_played = mechanics_played
  end

  def index
    @games = apply_params(@games, params)
    @games = sort(@games, params)
    @count = @games.count
    @games = limit(@games, params)
  end

  def random
    if params["permalink"]
      ids = Base64.decode64(params["permalink"]).split(',')
      games_by_id = @games.select { |g| g.id.in? ids }.index_by(&:id)
      @games = ids.map { |id| games_by_id[id] }
      @count = @games.count
      render :index
    else
      samples = []
      users = %w(hiimjosh iadena yourwhiteshadow Falcifer666 adamabsurd)
      users = (users * 2).shuffle
      [4, 5].shuffle.each do |n|
        user = users.shift
        samples += @games.recommended_with(n).filler.owned_by(user).to_a.sample(1)

        user = users.shift
        samples += @games.recommended_with(n).owned_by(user).select { |g| g.weight > 2 && g.weight < 3 }.sample(1)

        user = users.shift
        samples += @games.recommended_with(n).owned_by(user).select { |g| g.weight > 3 }.sample(1)
      end
      @games = samples.sort_by { |g| -g.weight }
      ids = @games.map(&:id).join(',')
      redirect_to random_path(permalink: Base64.encode64(ids))
    end
  end

  def mechanics_ranking
    scores = Hash.new { [] }
    @games.each do |game|
      game.mechanics.each do |mechanic|
        scores[mechanic] += game.player_ratings
      end
    end
    scores.transform_values do |ratings|
      size = [ratings.size, 1].max
      ratings.sum*1.0 / size
    end
  end

  def mechanics_played
    scores = Hash.new { 0 }
    @games.each do |game|
      game.mechanics.each do |mechanic|
        scores[mechanic] += game.num_raters
      end
    end
    scores
  end

  def limit(games, params)
    limit = params["limit"] || 500
    games.first(limit)
  end

  def sort(games, params)
    return games.stable_sort_by { |x| -x.num_raters }.stable_sort_by { |x| -x.median_player_rating } unless params["sort"]
    return games.to_a.shuffle if params["sort"] == "random"

    acc = games
    sorts = params["sort"].split(",")
    sorts.each do |sort|
      dir = 1
      value = sort

      if value[0] == "-"
        dir = -1
        value = value[1..-1]
      end

      if acc.first.respond_to?(value)
        acc = acc.stable_sort_by do |x|
          n = x.send(value)
          n = n.size if n.respond_to?(:each)
          dir * n
        end
      end
    end
    acc
  end

  def apply_params(games, params)
    acc = games
    params.each do |k, v|
      acc =
        case k
        when *SIMPLE_PARAMS
          v = maybe_upcast_data_type(v)
          if v.respond_to?(:call)
            acc.where { |g| v.call g.send(k) }
          else
            acc.where { |g| g.send(k) == v }
          end
        when *COLLECTION_PARAMS
          v = maybe_upcast_data_type(v)
          acc.send(k, v)
        else
          acc
        end
    end
    acc
  end

  def maybe_upcast_data_type(v)
    case v
    when /^[\s\d]+$/
      v.to_i
    when /^[\s\d\.]+$/
      v.to_f
    when /^\[[\s\w\d\.,]+\]$/
      v[1..-2].split(',').map { |val| maybe_upcast_data_type(val) }
    when /^lt[\d\.]+$/
      val = maybe_upcast_data_type(v[2..-1])
      -> (n) { n < val }
    when /^lte[\d\.]+$/
      val = maybe_upcast_data_type(v[3..-1])
      -> (n) { n <= val }
    when /^gt[\d\.]+$/
      val = maybe_upcast_data_type(v[2..-1])
      -> (n) { n > val }
    when /^gte[\d\.]+$/
      val = maybe_upcast_data_type(v[3..-1])
      -> (n) { n >= val }
    else
      v
    end
  end
end
