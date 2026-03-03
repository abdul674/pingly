class MessageProcessor
  def process(normalized)
    source = normalized[:source]
    return unless source

    message = source.messages.find_or_initialize_by(external_id: normalized[:external_id])
    return message if message.persisted?

    message.assign_attributes(
      sender_name: normalized[:sender_name],
      sender_avatar: normalized[:sender_avatar],
      content: normalized[:content],
      mentioned: normalized[:mentioned],
      deep_link: normalized[:deep_link],
      raw_data: normalized[:raw_data],
      received_at: normalized[:received_at] || Time.current
    )

    message.save!
    Categorizer.new.categorize!(message)
    message
  end
end
