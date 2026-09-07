# frozen_string_literal: true

module ImportBatches
  # Builds import job payloads. Includes a decrypted access token so the Python
  # worker can call Lichess without reading Active Record ciphertext via SQL.
  module JobPayload
    module_function

    def for(batch:, provider_account: batch.provider_account)
      {
        "import_batch_id" => batch.id,
        "access_token" => provider_account.access_token
      }
    end
  end
end
