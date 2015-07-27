class AddSimilarMasterToListings < ActiveRecord::Migration
  def change
    add_column :listings, :similar_master, :boolean
  end
end
