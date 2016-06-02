class AddPictureUrlsToListings < ActiveRecord::Migration
  def change
    add_column :listings, :picture_urls, :text
  end
end
