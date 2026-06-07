class KamiRelationship < ApplicationRecord
  belongs_to :source_kami, class_name: "Kami"
  belongs_to :target_kami, class_name: "Kami"

  enum :relationship_type, {
    spouse: 0,
    parent_child: 1
  }
end
