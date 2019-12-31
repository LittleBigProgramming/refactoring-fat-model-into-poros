# frozen_string_literal: true

class CalendarStylistListItem
  def initialize(stylist)
    @stylist = stylist
  end

  def manual_position
    @stylist.new_record? ? highest_manual_order_index + 1 : @stylist.manual_order_index
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

  def highest_manual_order_index
    salon.stylists.map(&:manual_order_index).max
  end

  def salon
    @stylist.salon
  end
end
