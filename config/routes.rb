require "sidekiq/web"
require "sidekiq-scheduler/web"

Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  # Route pour arrêter l'impersonation depuis l'admin
  namespace :admin do
    delete 'impersonation/:id', to: 'impersonation#destroy', as: 'impersonation'
  end

  draw(:base)
end
