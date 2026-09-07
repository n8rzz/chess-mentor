# frozen_string_literal: true

# Provider OAuth tokens are encrypted at rest. Production should set keys via
# Rails credentials (`rails db:encryption:init`) or ENV. Local/test derive keys
# from secret_key_base so encrypts works without editing credentials.
#
# support_unencrypted_data allows reading plaintext rows written before encryption.
Rails.application.configure do
  credentials_keys = Rails.application.credentials.active_record_encryption

  if credentials_keys.present?
    config.active_record.encryption.primary_key = credentials_keys[:primary_key]
    config.active_record.encryption.deterministic_key = credentials_keys[:deterministic_key]
    config.active_record.encryption.key_derivation_salt = credentials_keys[:key_derivation_salt]
  elsif ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].present?
    config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
    config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
  elsif Rails.env.local?
    digest = Digest::SHA256.digest(Rails.application.secret_key_base)
    config.active_record.encryption.primary_key = Base64.strict_encode64(digest)
    config.active_record.encryption.deterministic_key = Base64.strict_encode64(Digest::SHA256.digest("#{Rails.application.secret_key_base}-deterministic"))
    config.active_record.encryption.key_derivation_salt = Base64.strict_encode64(Digest::SHA256.digest("#{Rails.application.secret_key_base}-salt"))
  end

  config.active_record.encryption.support_unencrypted_data = true
end
