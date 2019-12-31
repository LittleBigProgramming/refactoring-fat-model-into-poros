class Stylist < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :with_active_salon, -> { joins(:salon).merge(Salon.active) }

  scope :non_receptionist, -> {
    joins('LEFT JOIN user_role ON user_role.user_id = stylist.user_id')
        .joins('LEFT JOIN role ON user_role.role_id = role.id')
        .where('role.code != ? OR role.code IS NULL', 'RECEPTIONIST')
  }

  belongs_to :salon
  belongs_to :user
  has_many :roles, through: :user
  belongs_to :stylist_employment_type
  has_many :stylist_services
  has_many :services, through: :stylist_services
  has_many :rent_payments
  has_many :appointments
  has_many :clients, through: :appointments
  attr_accessor :skip_saving_other_stylists

  accepts_nested_attributes_for :user, :allow_destroy => true, :reject_if => :all_blank

  after_initialize -> { self.skip_saving_other_stylists = false }
  before_save -> { make_sure_self_gets_correct_order_index }
  after_save -> { salon.reload.resave_stylists unless skip_saving_other_stylists }

  validates_presence_of :name
  validates_presence_of :salon

  validates_each :name do |model, attr, value|
    stylist = Stylist.find_by_name_and_salon_id(value, model.salon_id)
    if stylist != nil and stylist.id != model.id
      model.errors.add(attr, "A stylist with name \"#{value}\" already exists.")
    end
  end

  def service_length(service)
    ss = stylist_services.find_by_service_id(service.id)
    ss ? ss.length_in_minutes : ""
  end

  def service_price(service)
    ss = stylist_services.find_by_service_id(service.id)
    ss ? ss.price : ""
  end

  def unique_clients_ordered_by_name
    Client.select("client.*, TRIM(UPPER(client.name)) upper_name")
        .joins(:appointments)
        .where("appointment.stylist_id = ?", id)
        .uniq
        .order("upper_name")
  end

  def save_services(lengths, prices)
    stylist_services.destroy_all
    salon.services.active.each_with_index do |service, i|
      if lengths[i].to_i > 0 || prices[i].to_i > 0
        StylistService.create!(
            stylist_id: self.id,
            service_id: service.id,
            length_in_minutes: lengths[i],
            price: prices[i]
        )
      end
    end
  end

  def report(date)
    sql = "
      SELECT a.start_time,
             c.name client_name,
             ti.label item_label,
             CASE WHEN ti.is_taxed = true THEN ti.price * #{salon.tax_rate + 1}
                  ELSE ti.price
             END
        FROM appointment a
        JOIN transaction_item ti ON ti.appointment_id = a.id
        JOIN client c ON a.client_id = c.id
        JOIN stylist s ON a.stylist_id = s.id
       WHERE s.id = #{self.id}
         AND a.start_time >= '#{Date.parse(date).strftime}'
         AND a.start_time <= '#{(Date.parse(date) + 7).strftime}'
    ORDER BY a.start_time,
             c.name,
             ti.label
    "
    result = self.connection.select_all(sql)
    result
  end

  def save_services_for_demo
    [{:name => "Men's Haircut",   :price => 20, :length => 30},
     {:name => "Women's Haircut", :price => 20, :length => 40}].each do |service|
      s = Service.create(
          :name => service[:name],
          :price => service[:price],
          :salon_id => self.salon_id
      )
      StylistService.create(
          :service_id => s.id,
          :stylist_id => self.id,
          :length_in_minutes => service[:length]
      )
    end
  end

  def formatted_rent
    if self.rent > 0
      number_with_precision(self.rent, :precision => 2)
    else
      ""
    end
  end

  def formatted_service_commission_rate
    if self.service_commission_rate > 0
      number_with_precision(self.service_commission_rate, :precision => 2)
    else
      ""
    end
  end

  def formatted_retail_commission_rate
    if self.retail_commission_rate > 0
      number_with_precision(self.retail_commission_rate, :precision => 2)
    else
      ""
    end
  end

  def clean_values
    if self.rent == nil
      self.rent = 0
    end

    if self.service_commission_rate = nil
      self.service_commission_rate = 0
    end

    if self.retail_commission_rate = nil
      self.retail_commission_rate = 0
    end
  end

  def pay_rent(date = Time.zone.now)
    payment = RentPayment.new
    payment.date = date
    payment.stylist_id = self.id
    payment.amount = self.rent
    payment.save
  end

  def rent_payments
    RentPayment.find_all_by_stylist_id(self.id)
  end

  def new_rent_payment
    rp = RentPayment.new
    rp.date = Time.zone.today
    rp.stylist_id = self.id
    rp.amount = self.rent
    rp
  end

  def gross_service_sales(start_date, end_date)
    self.salon.earnings(start_date, end_date, self.id)['services'].to_f
  end

  def net_service_sales(start_date, end_date)
    self.gross_service_sales(start_date, end_date) * self.service_commission_rate
  end

  def gross_product_sales(start_date, end_date)
    self.salon.earnings(start_date, end_date, self.id)['products'].to_f
  end

  def net_product_sales(start_date, end_date)
    self.gross_product_sales(start_date, end_date) * self.retail_commission_rate
  end

  def self.everyone_stylist
    self.new(id: 0, name: 'All Stylists')
  end

  def make_sure_self_gets_correct_order_index
    self.cached_order_index = order_index
    self.manual_order_index = manual_position if salon.has_manual_order?
  end

  def has_appointment_at?(start_time)
    appointments.where("start_time = ? and is_cancelled = false", start_time).any?
  end

  def stylist_employment_type_code
    stylist_employment_type ? stylist_employment_type.code : ""
  end
end