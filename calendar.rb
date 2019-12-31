# frozen_string_literal: true

class Calendar
  def manual_position
    new_record? ? salon.highest_manual_order_index + 1 : manual_order_index
  end

  def alphabetical_position
    stylist_names = salon.ordered_stylist_names
    stylist_names << name unless stylist_names.member? name
    stylist_names.map(&:downcase).sort!.index(name.downcase)
  end

  def order_index
    return -1 unless active
    salon.has_manual_order? ? manual_position : alphabetical_position
  end
end
