# frozen_string_literal: true

module Decidim
  module Messaging
    #
    # Holds a chat or conversation between a number of participants. Each chat
    # would be equivalent to an entry in your Telegram conversation list, be it
    # a group or a one-to-one conversation.
    #
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

      scope :unread_by, lambda { |user|
        joins(:receipts).merge(Receipt.unread_by(user)).distinct
      }

      delegate :mark_as_read, to: :receipts

      #
      # Initiates a conversation between a user and a set of interlocutors with
      # an initial message. Works just like .start, but saves all the dependent
      # objects into DB.
      #
      # @param (see .start)
      #
      # @return (see .start)
      #
      def self.start!(originator:, interlocutors:, body:)
        chat = start(
          originator: originator,
          interlocutors: interlocutors,
          body: body
        )

        chat.save!

        chat
      end

      #
      # Initiates a conversation between a user and a set of interlocutors with
      # an initial message.
      #
      # @param originator [Decidim::User] The user starting the chat
      # @param interlocutors [Array<Decidim::User>] The set of interlocutors in
      #   the chat (not including the originator).
      # @param body [String] The content of the initial message
      #
      # @return [Decidim::Messaging::Chat] The newly created chat
      #
      def self.start(originator:, interlocutors:, body:)
        chat = new(participants: [originator] + interlocutors)

        chat.add_message(sender: originator, body: body)

        chat
      end

      # Appends a message to this chat and saves everything to DB.
      #
      # @param (see #add_message)
      #
      # @return (see #add_message)
      #
      def add_message!(sender:, body:)
        add_message(sender: sender, body: body)

        save!
      end

      #
      # Appends a message to this chat
      #
      # @param sender [Decidim::User] The sender of the message
      # @param body [String] The content of the message
      #
      # @return [Decidim::Messaging::Message] The newly created message
      #
      def add_message(sender:, body:)
        message = messages.build(sender: sender, body: body)

        message.envelope_for(interlocutors(sender))

        message
      end

      #
      # Given a user, returns her interlocutors in this conversation
      #
      # @param user [Decidim::User] The user to find interlocutors for
      #
      # @return [Array<Decidim::User>]
      #
      def interlocutors(user)
        participants.reject { |participant| participant.id == user.id }
      end

      #
      # The most recent message in this conversation
      #
      # @return [Decidim::Messaging::Message]
      #
      def last_message
        messages.last
      end

      #
      # The number of messages in this conversation a user has not yet read
      #
      # @return [Integer]
      #
      def unread_count(user)
        receipts.unread_by(user).count
      end
    end
  end
end
