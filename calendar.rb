# frozen_string_literal: true

class Calendar
  def initialize(stylist)
    @stylist = stylist
  end

  def manual_position
    @stylist.new_record? ? salon.highest_manual_order_index + 1 : @stylist.manual_order_index
  end

  def alphabetical_position
    stylist_names = salon.ordered_stylist_names
    stylist_names << @stylist.name unless stylist_names.member? @stylist.name
    stylist_names.map(&:downcase).sort!.index(@stylist.name.downcase)
  end

  def order_index
    return -1 unless @stylist.active

    @stylist.salon.has_manual_order? ? @stylist.manual_position : @stylist.alphabetical_position
  end

  private

  def salon
    @stylist.salon
  end
end
