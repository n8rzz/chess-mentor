# frozen_string_literal: true

# == Schema Information
#
# Table name: provider_accounts
#
#  id                :string           not null, primary key
#  access_token      :text
#  last_imported_at  :datetime
#  provider          :integer          default("lichess"), not null
#  provider_username :string           not null
#  refresh_token     :text
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
require "rails_helper"

RSpec.describe ProviderAccount, type: :model do
  subject(:provider_account) { build(:provider_account) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it do
      expect(provider_account).to define_enum_for(:provider)
        .with_values(lichess: 0, chess_com: 1)
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:provider_username) }
    it { is_expected.to validate_presence_of(:provider_user_id) }

    it "requires a unique provider_user_id per provider" do
      create(:provider_account, provider_user_id: "abc123")
      duplicate = build(:provider_account, provider_user_id: "abc123")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider_user_id]).to include("has already been taken")
    end

    it "allows one provider account per user per provider" do
      user = create(:user)
      create(:provider_account, user: user, provider: :lichess)
      duplicate = build(:provider_account, user: user, provider: :lichess, provider_user_id: "other-id")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider]).to include("has already been taken")
    end

    it "allows lichess and chess_com accounts for the same user" do
      user = create(:user)
      create(:provider_account, user: user, provider: :lichess)
      chess_com_account = build(:provider_account, :chess_com, user: user)

      expect(chess_com_account).to be_valid
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      provider_account.save!

      expect(provider_account.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
