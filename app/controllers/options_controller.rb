# Controller for master preferences for the application.

class OptionsController < ApplicationController
  
  before_filter :make_sure_root
  
  layout 'main'
  
  def make_sure_root
    if site_user and site_user.cnet == root_user_cnet
      return true
    else
      flash[:alert] = "Only the root user may make these changes."
      redirect_back_or_default :action => 'login', :controller => 'faculty'
      return false
    end
  end
  
  def index
    @options = $OPTIONS
  end
  
  def apply_settings
    @key = params[:value].keys.first.to_sym
    @value = params[:value].values.first
    $OPTIONS[@key] = @value
    File.open(RAILS_ROOT + '/config/options.yml', 'w') do |f|
      YAML.dump($OPTIONS, f)
    end
    render :action => 'update_slider'
  end
  
end
