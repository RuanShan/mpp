class Mobile::TripsController < Mobile::BaseController
  before_action :load_trip

  def index
    @body_class = 'index'

    @trip_ads = @trip.trip_ads.order(:sort)
    @category = @site.trip_ticket_categories.where(id: params[:trip_ticket_category_id]).first
    @trip_tickets = @trip.trip_tickets.online.latest.categorized(@category)

    if @site.website.try(:website_menus).to_a.select{|f| f.activity?}.flatten.select{|f| f.menuable_id == @trip.try(:activity).id}
      @url = mobile_root_url(site_id: @site.id)
    end
  end

  def show
    @trip_ticket = @trip.trip_tickets.find(params[:id])
  end

  private

  def load_trip
    @trip = @site.trip
  end

end

