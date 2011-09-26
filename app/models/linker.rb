class Linker < ActiveRecord::Base
  
  belongs_to :image
  belongs_to :linking, :polymorphic => true
  belongs_to :subsection, :class_name => "Subsection", :foreign_key => "linking_id"
  belongs_to :system, :class_name => "System", :foreign_key => "linking_id"
  
end
