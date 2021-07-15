class GameController < ApplicationController
  before_action do
    @games = $proxy.owned.not(:solo_only)
    @total = @games.count
  end

  def index
    @games = apply_params(@games, params)
    @games = sort(@games, params)
    @games = limit(@games, params)
  end

  def random
    if params["permalink"]
      ids = Base64.decode64(params["permalink"]).split(',')
      games_by_id = @games.select { |g| g.id.in? ids }.index_by(&:id)
      @games = ids.map { |id| games_by_id[id] }
      render :index
    else
      @games = $proxy.owned.not(:solo_only)
      @total = @games.count
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

  def most_want_to_play
    gen_filter { |games| games.sort_by { |g| -(g.want_to_players.count) }}
  end

  def already_know
    gen_filter { |games| games.sort_by { |g| -(g.raters.count) }}
  end

  def gen_filter
    @games = yield @games
    @games = limit(@games, params)
    render :index
  end

  def limit(games, params)
    limit = params["limit"] || 100
    games.first(limit)
  end

  def sort(games, params)
    if params["sort"]
      dir = 1
      value = params["sort"]

      if value[0] == "-"
        dir = -1
        value = value[1..-1]
      end

      if games.first.respond_to?(value)
        return games.sort_by { |x| dir * x.send(value) }
      end
    end

    games.sort_by { |x| -x.median_player_rating }
  end

  def apply_params(games, params)
    legacy = %w(
      best_with
      bgg_rank
      median_player_rating
      owners
      player_rating_summary
      recommended_with
      want_to_players
      weight
      playingtime
    )
    acc = games
    params.each do |k, v|
      case k
      when *legacy
        v = maybe_upcast_data_type(v)
        acc = acc.send(k, v)
      else
        acc = acc
      end
    end
    acc
  end

  def maybe_upcast_data_type(v)
    case v
    when /^\d+$/
      v.to_i
    when /^[\d\.]+$/
      v.to_f
    when /^\[[\d,]+\]$/
      v[1..-2].split(',').map(&:to_i)
    when /^\[[\d\.,]+\]$/
      v[1..-2].split(',').map(&:to_f)
    end
  end
end
