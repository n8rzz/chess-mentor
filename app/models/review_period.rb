# frozen_string_literal: true

# == Schema Information
#
# Table name: review_periods
#
#  id         :string           not null, primary key
#  ends_at    :datetime         not null
#  label      :string           not null
#  max_games  :integer
#  metadata   :jsonb            not null
#  starts_at  :datetime         not null
#  status     :integer          default("draft"), not null
#  time_class :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :string           not null
#
# Indexes
#
#  index_review_periods_on_user_id                            (user_id)
#  index_review_periods_on_user_id_and_starts_at_and_ends_at  (user_id,starts_at,ends_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class ReviewPeriod < ApplicationRecord
  belongs_to :user
  has_many :review_period_games, dependent: :destroy
  has_many :games, through: :review_period_games
  has_many :review_period_metrics, dependent: :destroy

  enum :status, {
    draft: 0,
    active: 1,
    completed: 2,
    archived: 3
  }, default: :draft, validate: true

  enum :time_class, {
    bullet: 0,
    blitz: 1,
    rapid: 2,
    classical: 3,
    unknown: 4
  }, validate: { allow_nil: true }, prefix: :time_class

  validates :label, :starts_at, :ends_at, presence: true
  validate :ends_at_after_starts_at

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at >= starts_at

    errors.add(:ends_at, "must be on or after starts_at")
  end
end
