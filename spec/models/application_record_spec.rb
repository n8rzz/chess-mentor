require "rails_helper"

RSpec.describe ApplicationRecord, type: :model do
  before(:all) do
    ActiveRecord::Schema.define do
      create_table :ulid_test_records, id: :string, force: :cascade do |t|
        t.string :name, null: false
      end
    end

    class UlidTestRecord < ApplicationRecord
      self.table_name = "ulid_test_records"
    end
  end

  after(:all) do
    ActiveRecord::Schema.define do
      drop_table :ulid_test_records, if_exists: true
    end

    Object.send(:remove_const, :UlidTestRecord)
  end

  it "assigns a ULID primary key on create" do
    record = UlidTestRecord.create!(name: "example")

    expect(record.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
  end

  it "does not overwrite an explicit id" do
    record = UlidTestRecord.create!(id: "01J0000000000000000000000", name: "example")

    expect(record.id).to eq("01J0000000000000000000000")
  end
end
