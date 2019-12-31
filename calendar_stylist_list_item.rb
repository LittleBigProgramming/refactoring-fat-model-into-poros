# frozen_string_literal: true

class CalendarStylistListItem
  def initialize(stylist)
    @stylist = stylist
  end

  def manual_position
    @stylist.new_record? ? highest_manual_order_index + 1 : @stylist.manual_order_index
  end

  def alphabetical_position
    stylist_names = ordered_stylist_names
    stylist_names << @stylist.name unless stylist_names.member? @stylist.name
    stylist_names.map(&:downcase).sort!.index(@stylist.name.downcase)
  end

  def order_index
    return -1 unless @stylist.active

    salon_has_manual_order? ? @stylist.manual_position : @stylist.alphabetical_position
  end

  private

  def highest_manual_order_index
    salon.stylists.map(&:manual_order_index).max
  end

  def ordered_stylist_names
    salon.stylists.active.non_receptionist
        .order(salon.attribute_by_which_to_order_stylists)
        .map(&:name)
  end

  def attribute_by_which_to_order_stylists
    salon_has_manual_order? ? 'stylist.manual_order_index' : 'LOWER(stylist.name)'
  end

  def salon_has_manual_order?
    salon.stylists.sum(:manual_order_index) > 0
  end

  def salon
    @stylist.salon
  end
end
