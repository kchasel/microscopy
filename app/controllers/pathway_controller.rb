class PathwayController < ApplicationController
  
  layout 'main'
  
  before_filter :check_logged_in, :except => [:view, :index]
  before_filter :get_all_pathways_and_items, :only => [:new, :edit]
  around_filter :only_public_items, :only => [:view]
  around_filter :only_public_for_students
  around_filter :only_own_pathways, :except => [:view, :index]
  
  # This ends up calling the view action from the Main controller, but using a different layout that adds the
  # pathway bar to the bottom.
  def view
    @pathway = Pathway.find(params[:id])
    if @pathway.pathway_items.empty?
      flash[:alert] = "This pathway is empty."
      redirect_back_or_default :action => 'index', :controller => 'main'
    else
      store_location
      @item = params[:image_id] ? @pathway.pathway_items.find_by_image_id(params[:image_id]) : @pathway.pathway_items.first
      @image = @item.image
      @images = Image.find(:all, :conditions => ["id != ?", @image.id])
      render :template => 'main/view', :layout => 'main_with_pathway_bar'
    end
  rescue
    debugger
    flash[:error] = "This pathway does not exist."
    redirect_to :action => 'index', :controller => 'main'
  end
  
  def new
      @pathway = Pathway.new(params[:pathway])
      if request.post?
        @pathway.faculty_id = site_user.id
        if @pathway.save
          redirect_to :action => 'view', :id => @pathway.id unless @pathway.frozen?
        end
      end
  end
  
  def index
    redirect_to :action => :new
  end
  
  def edit
    @pathway = Pathway.find(params[:id])
    if request.post?
      begin
        if @pathway.update_attributes(params[:pathway]) and not @pathway.frozen?
          redirect_to :action => 'view', :id => @pathway.id
        elsif @pathway.frozen?
          flash[:alert] = "The pathway #{@pathway.name} was deleted because it contained no more slides."
          redirect_to :action => 'index', :controller => 'faculty'
        end
      rescue
        flash[:alert] = "The pathway #{@pathway.name} was deleted because it contained no more slides."
        redirect_to :action => 'index', :controller => 'faculty'
      end
    end
  end
  
  def delete
    pathway = Pathway.find(params[:id])
    name = pathway.name
    if pathway.destroy
      flash[:success] = "The pathway #{name} was deleted."
      redirect_to :action => 'index', :controller => 'faculty'
    else
      flash.now[:error] = "Pathway could not be deleted."
    end
  end
  
  # Reload the images to select from on the new/edit pathway pages.
  def update_images
    if params[:course_id] == 'all' or params[:system_id] == 'all'
      @images = Image.find(:all, :select => "url, id", :conditions => (["images.id NOT IN (?)", params['new-pathway-list']] if params['new-pathway-list']))
    elsif params[:course_id]
      @images = Course.find(params[:course_id]).images(:all, (["images.id NOT IN (?)", params['new-pathway-list']] if params['new-pathway-list']), :select => "id, url")
    elsif params[:system_id]
       @images = System.find(params[:system_id]).images.find(:all, :select => "images.id, images.url", :conditions => (["images.id NOT IN (?)", params['new-pathway-list']] if params['new-pathway-list']))
    end
  rescue
    @images = []
  end
  
  private
  
  # Convenience method used in new and edit
  def get_all_pathways_and_items
    @all_pathways = is_root? ? Pathway.find(:all) : site_user.pathways
    @systems = System.find(:all, :select => "name, id")
    @courses = Course.find(:all, :select => "id, number")
  end
  
  # Only allow items (images) that have a status of public to be viewable.
  def only_public_items
    unless site_user
      PathwayItem.only_public do
        yield
      end
    else
      yield
    end
  end
  
  # Only allow a user to edit their own pathways.
  def only_own_pathways
    unless is_root?
      Pathway.only_own(site_user) do
        yield
      end
    else
      yield
    end
  end
  
end
