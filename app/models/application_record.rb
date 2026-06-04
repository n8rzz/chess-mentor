class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create :assign_ulid

  class << self
    def ulid_primary_key?
      return @ulid_primary_key if defined?(@ulid_primary_key)

      @ulid_primary_key = column_names.include?("id") && type_for_attribute(:id).type == :string
    end
  end

  private

  def assign_ulid
    return unless self.class.ulid_primary_key?
    return if id.present?

    self.id = ULID.generate
  end
end
