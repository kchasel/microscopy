# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def cancel_button(value, args = {})
    "<input type='button' value=\"#{value}\" onclick='location.href=\"#{session[:location] = nil ? url_for(args) : session[:location]}\";return(false);'>"
  end
  
end
