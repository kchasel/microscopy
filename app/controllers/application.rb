# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

# Application constants. Available in all controllers, models, helpers and views.

PUB_URL = RAILS_ROOT + '/public'
SYS_URL = PUB_URL + '/z_images'
UPLOAD_LOCATION = SYS_URL + "/upload"
Z_URL = '/z_images'

DEPT_CODE = ZoomifyVars::CONFIG[:dept_code]

class ApplicationController < ActionController::Base
  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_zoomify_session_id'
  
  # Prevent any passwords from being written to the log files
  filter_parameter_logging :password, :old_pass
  
  # ----Uncomment below for system-wide notice to all visitors. The notice may be edited below---- 
  # before_filter :system_notice
  
  def system_notice
    flash.now[:alert] = "The Virtual Microscopy system will be offline for scheduled maintenance on 
    Friday, May 9 from approximately 1:00pm-1:45pm CDT."
  end
  
  around_filter :always_private_slides
  
  # Helper methods
  
  def annotations_active
    return true if $OPTIONS[:annotations] == "1"
    return false
  end
  
  def accounts_active
    return true if $OPTIONS[:accounts] == "1"
    return false
  end
  
  def root_user_cnet
    ZoomifyVars::CONFIG[:shared_admin]
  end
  
  def is_root?
    return root_user_cnet == site_user.cnet if site_user
    return false
  end
  
  def site_user
    session[:user]
  end
  
  helper_method :site_user, :annotations_active, :root_user_cnet, :accounts_active, :is_root?
  
  # Allows backtracking to the last url. Apply this method to the top of an action.
  def store_location
    session[:location] = request.request_uri
  end
  
  # Returns to a store_location location if that method is defined, or the
  # default location if there is no store_location available
  def redirect_back_or_default(default)
    if location = session[:location]
      session[:location] = nil
      redirect_to location
    else
      redirect_to default
    end
  end
  
  # Below are a set of filters. These are executed either before, after, or around a called action.
  # Check the tops of the other controllers for which actions use them.
  
  protected
  
  # If the user is logged in as faculty, go ahead. Else direct to login.
  def check_logged_in
    if site_user
      # ----Uncomment the flash below for system-wide notice to faculty users. This message will override the systemwide
      # message defined above if both are active. ----
      # flash.now[:alert] = "The system will be offline for approximately 30 minutes January 11, 2008 at 3:00pm CST
      # for scheduled maintenance. Any uploads running at that time may fail, so please do not commence any uploads in the half
      # hour beforehand. This message will disappear when the maintenance is complete.
      # <br />Please contact #{ZoomifyVars::CONFIG[:designer_email]} with any questions. We're sorry for any inconvenience this may cause."
      return true
    else
      store_location
      redirect_to :action => 'login', :controller => 'faculty'
      return false
    end
  end
  
  # Only allow faculty to make changes to slides they own. Is not activated for administrators.
  def limit_faculty_to_self
    if site_user.admin == true
      yield
    else
      Image.only_edit_own(site_user) do
        yield
      end
    end
  end
  
  # Always active. Prevents slides with the status "private to all" from being visible to anyone except
  # their owner and the root user, defined in /config/environments/zoomify_environment.rb
  # Private to all slides are hidden from those not logged in under only_public_for_students
  def always_private_slides
    if site_user
      if site_user.cnet == root_user_cnet
        yield
      else
        Image.no_show_private_to_all(site_user) do
          yield
        end
      end
    else
      yield
    end
  end
  
  # Convenience method for determining if the current user has the right to edit something.
  def self_or_admin_only
    if site_user.id.to_s == params[:id].to_s or site_user.admin == true
      return true
    else
      flash[:error] = "You are not authorized to take this action."
      redirect_to :action => 'index', :controller => 'faculty'
      return false
    end
  end
  
  # Prevents private and private_to_all images from being found by anyone not logged in as faculty (ie students).
  def only_public_for_students
    unless site_user
      Image.only_public do
        yield
      end
    else
      yield
    end
  end
  
  # Require current user authentication using this method. Only recommended for important actions, such as account deletion.
  # The action should use delete, not post, as its method for delivering data.
  def check_user_pw
    if request.get?
      @action = action_name
      render :action => 'check_pw', :controller => 'faculty'
    elsif request.post?
      if Faculty.authenticate(site_user.cnet, params[:password]) and (params[:id] == site_user.id.to_s or site_user.admin == true)
        yield
      else
        flash[:error] = "You are not authorized to take this action."
        redirect_to :action => 'index', :controller => 'faculty'
      end
    elsif request.delete?
      yield
    else
      flash[:error] = "There was an error accessing the password check function.
      This action, #{action_name}, has been halted for security purposes. Please contact #{ZoomifyVars::CONFIG[:designer_email]}."
      redirect_to :action => 'index', :controller => 'faculty'
    end
  end
  
  # Require an administrator's authentication using this method. Only use for important methods, such as account deletion.
  # The action should use delete, not post, as its method for delivering data.
  def check_admin_pw
    if request.get?
      @action = action_name
      render :action => 'check_admin', :controller => 'faculty'
    elsif request.post?
      f = Faculty.find_by_cnet(params[:cnet])
      if Faculty.authenticate(f.cnet, params[:password]) and f.admin == true
        yield
      else
        flash[:error] = "You are not authorized to take this action."
        redirect_to :action => 'admin', :controller => 'faculty'
      end
    elsif request.delete?
      yield
    else
      flash[:error] = "There was an error accessing the password check function. Please contact #{ZoomifyVars::CONFIG[:designer_email]}."
      redirect_to :action => 'admin', :controller => 'faculty'
    end
  end
  
  # The master search function. Called by both the main and faculty controllers.
  # This function searches using different methods depending on the parameters included. If a section number is
  # included, (requiring the presence of a course number as well) it searches for images in that section. If only a course number is 
  # included, it searches images
  # in that course. If a system is included, it searches for that system's images. Finally, if nothing is included,
  # it searches all images. Note that this function should be used subordinate to the filters, so it will only find images that the
  # user has privileges to view (see only_public_for_students and always_private_slides above)
  def run_search
    st = params[:search]
    if params[:coursenum] and params[:sectionnum]
      @images = st == "" ? Course.find_by_number(params[:coursenum]).sections.find_by_number(params[:sectionnum]).images(:all, nil) : 
      Course.find_by_number(params[:coursenum]).sections.find_by_number(params[:sectionnum]).images(:all, ['lower(name) LIKE ?', '%' + st.downcase + '%'])
    elsif params[:coursenum]
      course = Course.find_by_number(params[:coursenum])
      @images = st == "" ? course.images : course.images(:all, ['name LIKE ?', '%' + st.downcase + '%'])
    elsif params[:system]
      @images = st == "" ? System.find_by_name(params[:system]).images : System.find_by_name(params[:system]).images.find(:all, :order => 'name', :conditions => ['lower(name) LIKE ?', '%' + st.downcase + '%'])
    else
      @images = st == "" ? Image.find(:all, :order => 'name') : Image.find(:all, :order => 'name', :conditions => ['
        lower(name) LIKE ?', '%' + st.downcase + '%'])
    end
    @img_ids = @images.collect { |i| i.id }
    @current = 'name'
  end

end