class AddMapToListings < ActiveRecord::Migration
  def change
    add_column :listings, :map_location, :string
  end
end
