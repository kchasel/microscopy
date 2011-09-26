namespace :public do
  
  desc "Clears the site images directories in /public and resets them."
  task :clearimgs do
    FileUtils.rm_r "#{RAILS_ROOT}/public/z_images" if File.exists?("#{RAILS_ROOT}/public/z_images")
    FileUtils.mkdir_p "#{RAILS_ROOT}/public/z_images/zips/"
    FileUtils.mkdir_p "#{RAILS_ROOT}/public/z_images/xml/"
    FileUtils.mkdir_p "#{RAILS_ROOT}/public/z_images/upload/"
  end

end
  
  desc "Performs all of the actions required to prepare this application for packaging/upload to a live server.
  Clears log and tmp files and removes all z_image files."
  task :prepare do
    puts "Clearing log files"
    Rake::Task["log:clear"].invoke
    puts "Clearing all tmp files"
    Rake::Task["tmp:clear"].invoke
    puts "Clearing out all images from public/z_images"
    Rake::Task["public:clearimgs"].invoke
  end