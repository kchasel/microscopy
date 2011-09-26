# The controller for the "main" application.

class MainController < ApplicationController
  
  around_filter :only_public_for_students # hide private images from students for all actions below
  
  def index
    store_location
    begin
    if params[:coursenum] and params[:sectionnum]
      course = Course.find_by_number(params[:coursenum])
      section = course.sections.find_by_number(params[:sectionnum])
      @images = section.images.sort { |x,y| x.name <=> y.name } || nil
    elsif params[:coursenum]
      @images = Course.find_by_number(params[:coursenum]).images.sort { |x,y| x.name <=> y.name }
    else
      @images = Image.find(:all, :order => 'name')
    end
    rescue
      @images = []
    end
    @img_ids = @images.collect { |i| i.id }
    @current = 'name'
    respond_to do |format|
      format.html
      format.xml { render :xml => @images.to_xml }
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
        respond_to do |format|
          format.html { render :action => 'index' }
          format.xml { render :xml => @images.to_xml }
        end
      end
    rescue
      redirect_to :action => 'index'
    end
  end
  
  # if the URL supplies a coursenum, sectionnum and name that meet the requirements in routes.rb, then view searches using these.
  # else it searches using the id. if either fail, it redirects to the main view page.
  def view
    store_location
    begin
      if params[:name]
        @image = Image.find_by_name(params[:name])
        if params[:sectionnum] and not Course.find_by_number(params[:coursenum]).sections.find_by_number(params[:sectionnum]).images.include?(@image)
          break
        end
      elsif params[:system]
          @image = System.find_by_name(params[:system]).images.find_by_name(params[:name])
          if @image == nil
            break
          end
      else
        @image = Image.find(params[:id])
      end
      images = Image.find(:all)
      @images = images - @image.to_a
      respond_to do |format|
        format.html
        format.xml { render :xml => @image }
      end
    rescue
      flash[:error] = "The requested slide could not be found."
      redirect_to :action => 'index', :format => 'html'
    end
  end
  
  # Loads a second slide onto the view page for comparison.
  def load_second_slide
    begin
      @image = Image.find(params[:id])
    rescue
      render :text => "No slide."
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
        @images = @img_ids.collect { |i| Image.find(i) }
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
    render :partial => 'image_list'
  end
  
  def search
  logger.silence do
    run_search
    render :partial => 'image_list'
  end
  end
  
end
