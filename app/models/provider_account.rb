# frozen_string_literal: true

# == Schema Information
#
# Table name: provider_accounts
#
#  id                :string           not null, primary key
#  access_token      :text
#  provider          :integer          default("lichess"), not null
#  provider_username :string           not null
#  token_expires_at  :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  provider_user_id  :string           not null
#  user_id           :string           not null
#
# Indexes
#
#  index_provider_accounts_on_provider_and_provider_user_id  (provider,provider_user_id) UNIQUE
#  index_provider_accounts_on_user_id                        (user_id)
#  index_provider_accounts_on_user_id_and_provider           (user_id,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class ProviderAccount < ApplicationRecord
  belongs_to :user

  enum :provider, { lichess: 0 }, validate: true

  validates :provider_username, presence: true
  validates :provider_user_id, presence: true
  validates :provider_user_id, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
end
