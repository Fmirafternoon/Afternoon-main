class Customer::BaseController < ApplicationController
  layout "customer"
  before_action :check_if_customer
  before_action :set_search_form

  private

  def check_if_customer
    unless current_user&.customer?
      redirect_to root_path, alert: "Vous n'êtes pas autorisé à accéder à cette page."
    end
  end

  def set_search_form
    @search_form = Customer::SearchForm.new(session[:search_form] || {})
  end

  def current_basket
    @current_basket ||= Basket.for_customer(current_user)
  end
  helper_method :current_basket
end
