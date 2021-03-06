class ListingsController < ApplicationController
  before_action :set_listing, only: [:show, :edit, :update, :destroy, :scrapeit, :add_similar]

  # GET /listings
  # GET /listings.json
  def index
    @show_deleted_and_no_image = params[:show_deleted]
    @hide_ugly = params[:hide_ugly]

    if @show_deleted_and_no_image
      @listings = Listing.order('created_at desc')
    elsif @hide_ugly
      @listings = Listing.where(deleted:false).where('ranking >2').where("img not like ?", "%nodisponible%").order('created_at desc')
    else
      @listings = Listing.where(deleted:false).where("img not like ?", "%nodisponible%").order('created_at desc')
    end


  end

  def duplicates
    # @duplicates = Listing.all.group_by{|elem| elem[:title]}.delete_if { |k, v| v.size == 1 }
    @duplicates_img = Listing.all.group_by{|elem| elem[:img]}.delete_if { |k, v| v.size == 1 }
    @duplicates = Picture.joins(:listing).select('listing_id AS id',:url,'listings.title AS title').group_by{|elem| elem[:url]}.delete_if { |k, v| v.size == 1 }.merge @duplicates_img
    @duplicates_title = Listing.order(:title).group_by{|elem| elem[:title]}.delete_if { |k, v| v.size == 1 }

  end

  def add_similar
    @listing.similar = [] if @listing.similar.nil?
    if params[:listing][:similar]
      @listing.similar << params[:listing][:similar]
      @listing.save
      similar_listing = Listing.find(params[:listing][:similar])
      similar_listing.similar = [] if similar_listing.similar.nil?
      similar_listing.similar << @listing.id
      similar_listing.save
    end
    redirect_to edit_listing_path(@listing.id), notice: 'Added similar listing.'
  end

  def external_scrape_gallito
    old_count = Listing.count
    Listing.scrape_gallito
    Listing.scrape_ml

    new_listing_count = Listing.count - old_count
    if new_listing_count > 0
      puts "Enviando email..."
      # NotificationMailer.new_listing_email(new_listing_count).deliver!
    else
      puts "nada nuevo"
      # NotificationMailer.new_listing_email(0).deliver!
    end
    puts "Fin."

    head :no_content
  end

  def scrape_all
    Listing.scrape_gallito
    Listing.scrape_ml
    redirect_to :root, notice: 'Listings scraped.'
  end
  def scrape_ml
    Listing.scrape_ml
    redirect_to :root, notice: 'Mercado Libre scraped!'
  end
  def scrape_gallito
    Listing.scrape_gallito
    redirect_to :root, notice: 'Gallito scraped!'
  end

  def scrape_gallito_estrenar
    Listing.scrape_gallito_estrenar
    redirect_to :root, notice: 'Gallito a estrenar scraped!'
  end  

  def scrapeit_ml
    agent = Mechanize.new
    page = agent.get(@listing.link)
    dolar_to_pesos = 31

    raw_listing = agent.page.search(".nav-main-content")

    # bring the pics again
    @listing.picture_urls.clear
    raw_pictures = raw_listing.search(".short-description-gallery-thumb img")
    raw_pictures.each do |raw_picture|
      picture_url = raw_picture.attributes['src'].text
      picture_url.sub! '-I.', '-F.'
      @listing.picture_urls << picture_url
    end
    @listing.save
    
    @listing.title = raw_listing.at('.vip-title-main').text
    @listing.description = raw_listing.search('.vip-description-container').map(&:text).join(' ')
    @listing.full_scraped = true

    sup_total = raw_listing.at(".attribute-group span:contains('Superficie construida')").next_element.text if raw_listing.at(".attribute-group span:contains('Superficie construida')")
    gc = raw_listing.at(".attribute-group span:contains('Expensas')").next_element.text if raw_listing.at(".attribute-group span:contains('Expensas')")
    @listing.gc = gc.gsub(/\D/, '') if gc.present?

    @listing.description = @listing.description+". "+sup_total if sup_total


    # @listing.map_location = raw_listing.at('#mapa img').attributes['src'].text if raw_listing.at('#mapa img')

    #Search duplicates
    dupes = Listing.where( title: @listing.title, description: @listing.description).order(:created_at)
    if dupes.size > 1
      dupe = dupes.first
      puts "dupe_____"+dupe.to_json
      @listing.comment = "" if @listing.comment.nil?
      @listing.comment = @listing.comment + " Duplicado: "+request.base_url+"/listings/"+dupe.id.to_s+"/edit"
    end
  end

  def scrapeit
    if @listing.link.include? 'mercadolibre'
      scrapeit_ml
    elsif @listing.link.include? 'gallito'
      scrapeit_gallito
    end
      flash.now[:notice] = 'scraped'
  end

  def scrapeit_gallito
    agent = Mechanize.new
    page = agent.get(@listing.link)
    dolar_to_pesos = 31

    raw_listing = agent.page.search(".contendor")

    @listing.picture_urls.clear
    raw_pictures = raw_listing.search(".sliderImg")
    raw_pictures.each do |raw_picture|
      picture = raw_picture.attributes['href'].text
      @listing.picture_urls << picture
    end
    @listing.save 
    
    @listing.title = raw_listing.at('.titulo').text
    @listing.description = raw_listing.at('#descripcionLarga').text.squish
    @listing.full_scraped = true

    sup_total = raw_listing.at("#primerosLi li:contains('Sup. Total:')").text if raw_listing.at("#primerosLi li:contains('Sup. Total:')")
    gc = raw_listing.at("#UlGenerales li:contains('Gastos Comunes:')").text if raw_listing.at("#UlGenerales li:contains('Gastos Comunes:')")
    @listing.gc = gc.gsub(/\D/, '') if gc.present?

    @listing.description = @listing.description+". "+sup_total if sup_total
  end

  # GET /listings/1
  # GET /listings/1.json
  def show
  end

  # GET /listings/new
  def new
    @listing = Listing.new
  end

  def edit
    scrapeit if !@listing.full_scraped
  end

  # POST /listings
  # POST /listings.json
  def create
    @listing = Listing.new(listing_params)

    respond_to do |format|
      if @listing.save
        format.html { redirect_to @listing, notice: 'Listing was successfully created.' }
        format.json { render :show, status: :created, location: @listing }
      else
        format.html { render :new }
        format.json { render json: @listing.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /listings/1
  # PATCH/PUT /listings/1.json
  def update
    respond_to do |format|
      if @listing.update(listing_params)
        format.html { redirect_to edit_listing_path(@listing.id), notice: 'Listing was successfully updated.' }
        format.json { render :show, status: :ok, location: @listing }
      else
        format.html { render :edit }
        format.json { render json: @listing.errors, status: :unprocessable_entity }
      end
    end

    # if @client.update(client_params)
    #   redirect_to admin_clients_path
    # else
    #   render :edit
    # end
  end

  # DELETE /listings/1
  # DELETE /listings/1.json
  def destroy
    @listing.deleted = true
    @listing.save
    respond_to do |format|
      format.html { redirect_to listings_url, notice: 'Listing was successfully destroyed.' }
      format.js {}
    end
  end

  def statistics
    start_date = Date.new(2015, 7, 10)
    @listings = Listing.where(created_at: start_date.beginning_of_day..Date.today.end_of_day).order(created_at: :desc).group_by{|x| x.created_at.strftime("%Y-%m-%d %A") }
    @listings_weekday = Listing.where(created_at: start_date.beginning_of_day..Date.today.end_of_day).order(created_at: :desc).group_by{|x| x.created_at.strftime("%A") }
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_listing
      @listing = Listing.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def listing_params
      params.require(:listing).permit(:full_scraped, :title, :price, :gc, :address, 
                                      :phone, :link, :description,:comment, :guarantee, 
                                      :ranking, :similar, :img, :map_location, {:picture_urls => []},
                                      :zone)
    end
end
