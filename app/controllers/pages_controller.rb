class PagesController < ApplicationController
 skip_before_action :authenticate_user!
 skip_after_action :verify_pundit_authorization

 def home
 html = File.read(Rails.root.join("public", "landing", "index.html"))

 auth_data = if user_signed_in?
 { signedIn: true, spaceUrl: current_user.agent? ? "/agent" : "/customer" }
 else
 { signedIn: false }
 end

 script_tag = "<script>window.__AFTERNOON_AUTH__ = #{auth_data.to_json};</script>"
 html = html.sub("</head>", "#{script_tag}</head>")

 render html: html.html_safe, layout: false
 end
end
