class FacultyController < ApplicationController
  
  # make sure only faculty can access all the following
  # actions with these exceptions.
  before_filter :check_logged_in, :except => [:login] 
  # only allows a faculty user to access slides that belong to him/her
  around_filter :limit_faculty_to_self, :except => [:index, :reorganize, :search, :system, :login, :system]
  # Only the current user or an admin may take these actions
  before_filter :self_or_admin_only, :only => [:delete_user, :delete_account]
  # Authenticate the current user before performing these actions. 
  around_filter :check_user_pw, :only => [:make_me_admin, :delete_account]
  # Require an administrator approval to perform these actions.
  around_filter :check_admin_pw, :only => [:make_admin, :remove_admin, :new_root_pw]
  
  layout 'main'
  
  def login
    if request.post?
      if Faculty.authenticate(params[:cnet], params[:password])
        session[:user] = Faculty.find_or_create_by_cnet(params[:cnet])
        if session[:user].preferences[:login_page] == 'management'
          redirect_to :action => 'index'
        elsif session[:user].preferences[:login_page] == 'main'
          redirect_to :action => 'index', :controller => 'main'
        end
      else
        flash.now[:error] = "Login failed. Please check your username and password and try again."
      end
    end
  end
  
  def logout
    session[:user] = nil
    redirect_back_or_default :action => 'index', :controller => 'main'
  end
  
  def index
    store_location
    begin
    if params[:coursenum] and params[:sectionnum]
      course = Course.find_by_number(params[:coursenum])
      section = course.sections.find_by_number(params[:sectionnum])
      @images = section.images.sort { |x,y| x.id <=> y.id } || nil
    elsif params[:coursenum]
      @images = Course.find_by_number(params[:coursenum]).images.sort { |x,y| x.id <=> y.id }
    else
      @images = Image.find(:all, :order => 'id')
    end
    rescue
      @images = []
    end
    @img_ids = @images.collect { |i| i.id }
    @current = 'id'
  end
  
  def search
  logger.silence do
    run_search
    render :partial => 'faculty_list'
  end
  end
  
  # Flips the images in the list. If a YAML @images array is passed, converts it back to an array of image objects
  # and sorts it by the given type. If no @images array is passed, finds all images in the system and arranges by name.
  def reorganize
    begin
      if params[:type]
        type = params[:type]
        @img_ids = YAML.load(params[:images])
        @img_ids.reverse! if type == params[:current]
        @images = @img_ids.collect { |i| Image.find(i)}
        if not type == params[:current]
          @images.sort! { |a,b| a[type] <=> b[type] }
          @img_ids = @images.collect { |i| i.id }
        end
      else
        @images = Image.find(:all, :order => 'name')
        @img_ids = @images.collect { |i| i.id }
      end
    rescue
      @images = Image.find(:all, :order => 'name')
      flash.now[:innerwarning] = "There was an error in sorting. List has been reset."
    end
    @current = type ? type : 'name'
    render :partial => 'faculty_list'
  end
  
  # Updates the status of an image
  def update_status
    @image = Image.find(params[:id])
    @image.update_attribute('status', params[:status])
  end
  
  def courses
    redirect_to :action => 'index', :controller => 'courses'
  end
  
  # Handles adding a new slide. Much of the action occurs in the Image model (image.rb in models)
  def add_slide
    @courses = Course.find :all
    @systems = System.find :all
    @image = Image.new(params[:image])
    @image.faculty_id = site_user.id
    if request.post? # do the following only when the request is a post (form was submitted)
      if @image.valid?
        if @image.save
           redirect_to :action => 'annotate', :controller => 'faculty', :id => @image.id
        else
           flash.now[:error] = "There was an error saving this slide."
         end
       end
     end
  end
  
  def course
    redirect_to :action => :index, :controller => :course
  end
  
  # Handles batch uploads. Most of the action happens in the Image model.
  def batch_upload
    if site_user.cnet == root_user_cnet
    dir = Dir.new(UPLOAD_LOCATION)
    @names = []
    dir.each do |x|
      if x[0] != "."[0]
        @names << x
      end
    end
    if request.post?
      flash[:error] = ""
      @names.each do |n|
        i = Image.new(:name => n, :z_name => n, :magnification => 20, :batch => true,
        :faculty_id => site_user.id, :status => 'private', :show_annotations => Time.now)
        if i.save == false
          flash[:error] += "<li>#{i.name}</li>"
          # return false
        end
      end
      if flash[:error] != ""
        flash[:error] += "These slides were not uploaded because they already exist in the system."
      else
        flash[:error] = nil
        flash[:success] = "All slides added to database."
      end
      redirect_to :action => "index"
    end
  else
      redirect_to :action => "index"
    end
  end
  
  def system
    begin
      unless params[:system]
        redirect_to :action => 'index'
      else
        @images = System.find_by_name(params[:system]).images
        @img_ids = @images.collect { |i| i.id }
        @current = 'name'
        render :action => 'index'
      end
    rescue
      redirect_to :action => 'index'
    end
  end
  
  def batch_edit
    @images = Image.find(:all)
    @systems = System.find :all
    if request.post?
      @images = []
      begin
        params[:images].each { |id| @images << Image.find(id) }
        if params[:image]
          @images.each do |i|
            if not i.update_attributes(params[:image])
              @image = i
              raise "Your attributes are not valid."
            end
          end
        end
        flash[:success] = "The selected slides were updated."
        redirect_to :action => 'index'
      rescue
        flash.now[:error] = "Choose some slides and try again." if not params[:images]
        @images = Image.find :all
      end
    end 
  end
  
  # Makes the slide's annotations visible to students immediately
  def show_slide_now
    @image = Image.find(params[:id])
    @image.show_now
    render :action => 'update_status'
  end
  
  def delete_slide
    image = Image.find(params[:id])
    image.destroy
    flash[:success] = "The file #{image.z_name} was deleted."
    redirect_to :action => 'index'
  end
  
  def edit
    @courses = Course.find :all
    @systems = System.find :all
    @image = Image.find_by_id(params[:id])
    if request.post? and (@image.faculty.id == site_user.id or site_user.admin == true)
      if @image.update_attributes(params[:image])
        flash[:success] = "The changes to #{params[:image][:name]} were saved."
        redirect_back_or_default :action => 'index'
      end
    end
  end
  
  def annotate
    store_location
    begin
      @image = Image.find(params[:id])
    rescue
      flash[:error] = "You are not authorized to annotate the requested slide."
      redirect_to :action => 'index', :controller => 'faculty'
    end
  end

  def admin
    if site_user.admin == true
      store_location
      @num_admins = Faculty.count(:all, :conditions => ["admin = ?", true])
      @users = Faculty.find(:all)
      list_users = Faculty.read_users_file
      @not_subscribed = list_users - @users.collect { |u| u.cnet }
      @not_allowed = @users.collect { |u| u.cnet } - list_users
    else
      redirect_to :action => 'index'
    end
  end
  
  def add_to_users_list
    if site_user.admin == true
      username = params[:cnet]
      if Faculty.write_to_users_list(username) == true
        flash[:success] = "#{username} added to allowed users list."
        redirect_back_or_default :action => 'admin'
      else
        flash[:alert] = "#{username} is already on the allowed users list."
        redirect_back_or_default :action => 'admin'
      end
    else
      redirect_to :action => 'index'
    end
  end
  
  def remove_from_users_list
    if site_user.admin == true
      username = params[:cnet]
      if Faculty.remove_from_users_list(username) == true
        flash[:success] = "#{username} removed from allowed users list. #{ "Once you logout, 
        another administrator must add you to the list again for you to login again." if site_user.cnet == username }"
        redirect_back_or_default :action => 'admin'
      else
        flash[:alert] = "#{username} could not be removed because it is not on the allowed users list."
        redirect_back_or_default :action => 'admin'
      end
    else
      redirect_to :action => 'index'
    end
  end
  
  def account
    store_location
    @faculty = Faculty.find(site_user.id)
    @images = Image.find(:all, :order => 'name')
    @img_ids = @images.collect { |i| i.id }
    @current = 'name'
  end
  
  def update_user_prefs
    Faculty.find(site_user.id).update_attributes(params[:faculty])
    respond_to do |format|
      format.html { redirect_to :action => 'account' }
      format.js
    end
  end
  
  def make_admin
    to_admin = Faculty.find(params[:id])
    if to_admin.adminify
      flash[:success] = "#{to_admin.cnet} is now an administrator."
      redirect_to :action => 'index', :controller => 'faculty'
    else
      flash[:error] = "Admin process failed."
      redirect_to :action => 'account', :controller => 'faculty'
    end
  end
  
  # Allows a user to make himself/herself an administrator only if there are no existing administrators of the system.
  # Deactivated because there will always be a root user.
=begin
  def make_me_admin
    if Faculty.count(:all, :conditions => ['admin', true]) == 0
      to_admin = site_user
      if to_admin.adminify
        session[:user] = to_admin.reload
        flash[:success] = "#{to_admin.cnet} is now an administrator."
        redirect_to :action => 'index', :controller => 'faculty'
      else
        flash[:error] = "Admin process failed."
        redirect_to :action => 'account', :controller => 'faculty'
      end
    else
      flash[:error] = "There are existing admins. You may only be made an admin by one of them."
      redirect_to :action => 'account'
    end
  end
=end
  
  def remove_admin
    rm_admin = Faculty.find(params[:id])
    if rm_admin.unadminify
      session[:user] = rm_admin.reload if rm_admin.id.to_s == site_user.id.to_s
      flash[:success] = "#{rm_admin.cnet} is no longer an administrator."
      redirect_to :action => 'index', :controller => 'faculty'
    else
      flash[:error] = "Admin Removal process failed. Note the root administrator cannot be unadminified."
      redirect_to :action => 'account', :controller => 'faculty'
    end
  end
  
  def new_root_pw
    Faculty.new_root_pw
    flash[:success] = "The root password has been changed. The new password has been e-mailed to the site owner."
    redirect_to :action => 'admin'
  end
  
  def change_root_pw
    unless site_user.cnet == root_user_cnet
      flash[:error] = "Only the root user may change the root password to a specific value. 
      To reset the root password to a randomized string, login as an administrator."
      redirect_back_or_default :action => 'admin'
    end
  end
  
  def do_root_pw_change
    if Faculty.authenticate_shared(params[:old_pass])
      Faculty.change_root_password(params[:password])
      flash[:success] = "The root password has been changed. The new password has been e-mailed to the site owner."
      redirect_to :action => 'admin'
    else
      flash[:error] = "The old password you entered was incorrect."
      redirect_to :action => 'change_root_pw'
    end
  end
    
  def delete_account
    @to_delete = Faculty.find(params[:id])
    # The shared admin user (defined in config/zoomify_environment.rb) cannot be deleted!
    if @to_delete.cnet == root_user_cnet
      flash[:error] = "The user #{root_user_cnet} is the general administrator and cannot be deleted."
      redirect_back_or_default :action => 'admin'
    end
    @images = @to_delete.images
    if request.delete?
    if params[:commit] == "Save all #{@to_delete.cnet}'s slides to my account, then delete #{@to_delete.cnet}"
      @to_delete.images.each { |s| s.transfer_to(site_user) }
      @to_delete.images.reload
      @to_delete.destroy
      flash[:success] = "#{@to_delete.cnet} deleted. Their slides were transferred to your account."
      redirect_to :action => 'admin'
    elsif params[:commit] == "Delete #{@to_delete.cnet}'s slides, then delete #{@to_delete.cnet}"
      session[:user] = nil if @to_delete.id.to_s == site_user.id.to_s
      @to_delete.destroy
      flash[:success] = "#{@to_delete.cnet} deleted. Their slides were deleted as well."
      redirect_to :action => 'admin'
    else
      flash[:error] = "There was an error. Please try again."
    end
    end
  end
  
  
end
