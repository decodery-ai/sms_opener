# frozen_string_literal: true

SmsOpener::Engine.routes.draw do
  root to: "messages#index"

  resources :messages, only: %i[index show create destroy] do
    collection do
      match :clear, via: %i[post delete]
    end
    member do
      post :delete, action: :destroy
    end
  end
end
