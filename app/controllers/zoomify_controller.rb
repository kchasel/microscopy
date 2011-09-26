# This controller is used only to save the annotations. The save action is called directly
# by the Zoomify application upon saving an annotation or POI.

class ZoomifyController < ApplicationController
  
  before_filter :check_logged_in
  
  def save
    xmlfile_server_path = params[:file]
    xmlfile_path = PUB_URL + xmlfile_server_path
    sanitized = sanitize_quotes(params["<ZAS><POI x"])
    
    File.open(xmlfile_path, "wb") do |f|
      f.write("<ZAS><POI x=" + sanitized)
    end
    
    render :text => "Success! Saved to #{xmlfile_server_path}"
  end
  
  # This method removes double quotes from user text entry and replaces them with single quotes, to prevent
  # a messed up XML file for the slide. The regexp searches for the text= and name= identifiers in the passed
  # XML.
  def sanitize_quotes(s)
    s.gsub(/text=".+?(?= user=)|name=".+?(?= (poiID=|\/>|movieClip=))/) do |m|
      m.gsub!(/"/, "'")
      m[5] = "\""
      m[m.length-1] = "\""
      m
    end
  end
  
end
