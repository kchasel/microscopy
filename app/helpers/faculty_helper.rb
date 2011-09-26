module FacultyHelper
  
  def allowed(item)
    item.faculty_id == site_user.id or site_user.admin == true
  end
  
end
