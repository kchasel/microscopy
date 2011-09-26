class Faculty < ActiveRecord::Base
  
  require 'net/ldap'
  
  has_many :images, :dependent => :destroy
  has_many :pathways
  
  serialize :preferences, Hash
  
  # Prevents the admin and salt values from being written to except explicitly (no mass definitions)
  attr_protected :admin, :salt
  
  # The LDAP address used by the University's LDAP server.
  # "uid=#{username},ou=people,dc=uchicago,dc=edu"
  
  # Authenticates a user. Uses two different methods depending on whether the user is attempting to login
  # as the shared root admin (not a University CNetID account) or using a CNetID. In the first case, it redirects
  # to the authenticate_shared method to authenticate the root user. Otherwise, a new connection is made
  # to the University's LDAP server (ldap.uchicago.edu). The input CNetID (username) is then verified as allowed
  # by checking both the allowed users list (/config/allowed_users.txt) and the permanent users list (defined
  # in /config/environments/zoomify_environment.rb). If the CNetID is on at least one of these lists, a bind is attempted
  # using the passed password and CNet against the University's LDAP server. If this succeeds, true is returned.
  # Otherwise, false is returned.
  def self.authenticate(username, password)
    if username == ZoomifyVars::CONFIG[:shared_admin]
      authenticate_shared(password)
    else
      ldap = Net::LDAP.new :host => 'ldap.uchicago.edu',
      :port => 636,
      :encryption => :simple_tls,
      :base => "dc=uchicago,dc=edu",
      :auth => { :method => :simple, :username => "uid=#{username},ou=people,dc=uchicago,dc=edu", :password => password }
      # 
      begin
      if (ZoomifyVars::CONFIG[:allowed_users].include?(username) or on_users_list(username)) and ldap.bind and $OPTIONS[:accounts] == "1"
        return true
      else
        return false
      end
      rescue
        return false
      end
    end
  end
  
  # Authenticates the shared root user (defined in /config/environments/zoomify_environment.rb).
  def self.authenticate_shared(password)
    sa = Faculty.find_by_cnet(ZoomifyVars::CONFIG[:shared_admin])
    if Faculty.encrypt(password, sa.salt) == sa.hashed_password
      if sa.admin == false # The shared admin is an admin always so make them one if for some reason they're not already
        sa.update_attribute(:admin, true)
      end
      return true
    else
      return false
    end
  end
  
  # Remove as an administrator, unless is the shared admin.
  def unadminify
    update_attribute('admin', false) if cnet != ZoomifyVars::CONFIG[:shared_admin]
  end
  
  # Make an administrator
  def adminify
    update_attribute('admin', true)
  end
  
  # Hashes and salts pass. Also creates a new salt for this Faculty if one does not already exist.
  def password=(pass)
    @password = pass
    self.salt = Faculty.random_string(10) if !self.salt? # Generate a salt if one does not already exist
    self.hashed_password = Faculty.encrypt(@password, self.salt)
  end
  
  # Creates a new, random password for the root user and e-mails it to the system admin 
  # e-mail (defined in zoomify_environment.rb)
  def self.new_root_pw
    sa = Faculty.find_by_cnet(ZoomifyVars::CONFIG[:shared_admin])
    newpass = Faculty.random_string(10)
    sa.password = newpass
    sa.save
    PasswordInfo.deliver_forgotten_root_pw(newpass)
    return newpass
  end
  
  # Changes the root user password to a set value.
  
  def self.change_root_password(newpass)
    sa = Faculty.find_by_cnet(ZoomifyVars::CONFIG[:shared_admin])
    sa.password = newpass
    sa.save
    PasswordInfo.deliver_new_root_pw(newpass)
  end
  
  private # Anything past this point may only be called by a function in this file
  
  # Reads /config/allowed_users.txt and returns an array of all CNets in the file
  def self.read_users_file
    a = []
    File.open(RAILS_ROOT + '/config/allowed_users.txt', "r") do |f|
      f.each do |line|
        line.strip!
        a << line if line[0] != "#"[0]
      end
    end
    return a
  end
  
  # Check to see if the username is on /config/allowed_users.txt
  def self.on_users_list(username)
    a = read_users_file
    if a.include?(username)
      return true
    else
      return false
    end
  end
  
  def self.write_to_users_list(username)
    File.open(RAILS_ROOT + '/config/allowed_users.txt', "r+") do |f|
      if not on_users_list(username) and not username == ""
        if f.readlines.last.include? "\n"
          f.puts("#{username}")
        else
          f.puts("\n#{username}")
        end
        return true
      else
        return false
      end
    end
  end
  
  def self.remove_from_users_list(username)
    oldfile = RAILS_ROOT + '/config/allowed_users.txt'
    newfile = RAILS_ROOT + '/config/allowed_users_new.txt'
    if on_users_list(username)
      File.open(oldfile) do |old|
        File.open(newfile, "w+") do |newfile|
          old.each { |line| newfile.puts line unless line.chomp == username }
        end
      end
      FileUtils.mv(RAILS_ROOT + '/config/allowed_users_new.txt', RAILS_ROOT + '/config/allowed_users.txt')
      return true
    else
      return false
    end
  end
        
  
  # Encrypt the passed password (pass) with the passed salt (salt) in SHA1 format
  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass+salt)
  end
  
  # Generates a random string composed of letters and numbers, of length len
  def self.random_string(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end
  
end
