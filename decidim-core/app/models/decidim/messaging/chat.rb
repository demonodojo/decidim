# frozen_string_literal: true

module Decidim
  module Messaging
    class Chat < ApplicationRecord
      has_many :participations, foreign_key: :decidim_chat_id,
                                class_name: "Decidim::Messaging::Participation",
                                dependent: :destroy,
                                inverse_of: :chat

      has_many :participants, through: :participations

      has_many :messages, foreign_key: :decidim_chat_id,
                          class_name: "Decidim::Messaging::Message",
                          dependent: :destroy,
                          inverse_of: :chat

      has_many :receipts, through: :messages

      delegate :mark_as_read, to: :receipts

      def self.start!(originator:, interlocutors:, body:)
        chat = start(
          originator: originator,
          interlocutors: interlocutors,
          body: body
        )

        chat.save!

        chat
      end

      def self.start(originator:, interlocutors:, body:)
        chat = new(participants: [originator] + interlocutors)

        chat.add_message(sender: originator, body: body)

        chat
      end

      def add_message(sender:, body:)
        message = messages.build(sender: sender, body: body)

        message.envelope_for(interlocutors(sender))

        message
      end

      def interlocutors(user)
        participants.reject { |participant| participant.id == user.id }
      end

      def last_message
        messages.last
      end

      def unread_count(user)
        receipts.unread_by(user).count
      end
    end
  end
end
