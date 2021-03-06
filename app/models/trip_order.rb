class TripOrder < ActiveRecord::Base
  #status:状态（1:已预约、2:已取消、3:已过期）
  belongs_to :site
  belongs_to :user
  belongs_to :trip
  belongs_to :trip_ticket

  validates :username, :tel, presence: true

  before_save :set_default_attrs

  private

  def set_default_attrs
    self.order_no = Concerns::OrderNoGenerator.generate
    self.total_amount = self.qty * self.price

    return unless self.trip

    self.site_id = self.trip.site_id
  end
end
