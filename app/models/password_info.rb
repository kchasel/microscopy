# This model file defines the e-mails sent out regarding root password changes.

class PasswordInfo < ActionMailer::Base
  
  def forgotten_root_pw(newpass)
    recipients ZoomifyVars::CONFIG[:admin_email]
    from ZoomifyVars::CONFIG[:admin_email]
    subject "[UCH Microscopy] Root Password"
    body :url => url_for(:host => ZoomifyVars::CONFIG[:host_url], :action => 'account', :controller => 'faculty'), 
    :root_username => ZoomifyVars::CONFIG[:shared_admin], :password => newpass
  end
  
  def new_root_pw(newpass)
    recipients ZoomifyVars::CONFIG[:admin_email]
    from ZoomifyVars::CONFIG[:admin_email]
    subject "[UCH Microscopy] Root Password"
    body :url => url_for(:host => ZoomifyVars::CONFIG[:host_url], :action => 'account', :controller => 'faculty'), 
    :root_username => ZoomifyVars::CONFIG[:shared_admin], :password => newpass, 
    :designer => ZoomifyVars::CONFIG[:designer_email]
  end
  
end
