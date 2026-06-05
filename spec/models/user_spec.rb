# == Schema Information
#
# Table name: users
#
#  id                     :string           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("member"), not null
#  unconfirmed_email      :string
#  username               :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_username              (username) UNIQUE
#
require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:system_jobs).dependent(:destroy) }
    it { is_expected.to have_many(:provider_accounts).dependent(:destroy) }
    it { is_expected.to have_many(:import_batches).dependent(:destroy) }
    it { is_expected.to have_many(:games).dependent(:destroy) }
    it { is_expected.to have_many(:weakness_cycles).dependent(:destroy) }
    it { is_expected.to have_many(:training_plans).dependent(:destroy) }
    it { is_expected.to have_many(:progress_snapshots).dependent(:destroy) }
    it { is_expected.to define_enum_for(:role).with_values(member: 0, admin: 1).backed_by_column_of_type(:integer) }

    it "destroys associated system jobs when the user is destroyed" do
      user = create(:user)
      create(:system_job, user: user)

      expect { user.destroy! }.to change(SystemJob, :count).by(-1)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
    it { is_expected.to validate_length_of(:username).is_at_least(3).is_at_most(30) }

    it "rejects invalid usernames" do
      user.username = "bad name"

      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("only allows letters, numbers, and underscores")
    end
  end

  describe "devise modules" do
    it "is database authenticatable and confirmable" do
      expect(described_class.devise_modules).to include(:database_authenticatable, :confirmable)
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      user.save!

      expect(user.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
