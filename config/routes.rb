Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "game#index"

  %w(random hidden_gems).each do |action|
    get "/#{action}", to: "game##{action}"
  end
end
