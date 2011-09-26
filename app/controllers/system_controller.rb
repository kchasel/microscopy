class SystemController < ApplicationController
  
  before_filter :check_logged_in, :except => [:index, :search]
  
  layout 'main'
  
  def index
    store_location
    @systems = System.find :all
    respond_to do |format|
      format.html
      format.xml { render :xml => @systems.to_xml }
    end
  end
  
  def new
    @system = System.new(params[:system])
    if request.get?
      redirect_to :action => 'index'
    elsif request.post?
      if @system.save
        flash[:success] = "The #{@system.name} system has been saved."
        redirect_to :action => 'index'
      end
    end
  end
  
  def search
    unless params[:search] == nil or params[:search] == ""
      @systems = System.find(:all, :conditions => ["name LIKE ?", '%' + params[:search] + '%'])
    else
      @systems = System.find :all
    end
    render :partial => 'system_list'
  end
  
  def delete
    system = System.find(params[:id])
    name = system.name
    if system.destroy
      flash[:success] = "The #{name} system was deleted."
      redirect_to :action => 'index'
    end
  end  
    
end
