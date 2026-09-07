# Chess Mentor

## Deploy

### Active Record encryption (provider OAuth tokens)

Provider account `access_token` / `refresh_token` values are encrypted at rest.

**Local and test** derive keys from `secret_key_base` automatically — no manual step.

**Production / staging** must configure encryption keys before boot, or token encryption will fail:

1. Generate keys:

```bash
bin/rails db:encryption:init
```

1. Store them either in Rails credentials under `active_record_encryption`:

```yaml
active_record_encryption:
  primary_key: ...
  deterministic_key: ...
  key_derivation_salt: ...
```

Or as environment variables:

```bash
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

Existing plaintext tokens remain readable (`support_unencrypted_data` is enabled) and are rewritten encrypted on the next save of those rows.

Import jobs receive a short-lived decrypted `access_token` in the system job payload (the Python worker cannot decrypt Active Record ciphertext). The token is removed from the payload when the job finishes.

Keep encryption keys stable across deploys. Rotating them without a re-encrypt migration will make existing ciphertext unreadable.
