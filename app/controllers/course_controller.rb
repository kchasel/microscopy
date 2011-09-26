class CourseController < ApplicationController
  
  before_filter :check_logged_in, :except => [:index, :search]
  
  layout 'main'
  
  def index
    store_location
    @courses = Course.find :all, :order => :number
    respond_to do |format|
      format.html
      format.xml { render :xml => @courses.to_xml(:include => [:sections, :subsections]) }
    end
  end
  
  def search
    unless params[:search] == nil or params[:search] == ""
      @courses = Course.find(:all, :order => :number, :conditions => ["number LIKE ?", '%' + params[:search] + '%'])
    else
      @courses = Course.find :all, :order => :number
    end
    render :partial => 'course_list'
  end
  
  def new
    @course = Course.new(params[:course])
    if request.post?
      if @course.save
        redirect_to :action => 'index'
      end
    end
  end
  
  def edit
    @course = Course.find(params[:id])
    if request.post?
      if @course.update_attributes(params[:course])
        redirect_to :action => 'index'
      end
    end
  end
  
  def delete
    course = Course.find(params[:id])
    number = course.number
    if course.destroy
      flash[:success] = "#{DEPT_CODE} #{number} was deleted."
      redirect_to :action => 'index'
    end
  end
  
end
