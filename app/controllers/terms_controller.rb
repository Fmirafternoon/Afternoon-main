class TermsController < ApplicationController
  layout "terms"
  def new
    terms_file = Dir["#{Rails.root}/public/terms/*-cgv.md"].max_by { |f| File.basename(f) }
    text = File.read(terms_file)

    @terms_html = Kramdown::Document.new(text).to_html
    authorize(:term)
  end

  def create
    authorize(:term)
    current_user.update(terms_accepted_at: DateTime.now)
    redirect_to root_path
  end
end
