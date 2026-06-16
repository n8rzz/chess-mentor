---
title: M1 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - authentication
  - oauth
  - milestone-1
---

# M1 manual testing checklist

Use this checklist for **Milestone 1: Authentication & provider OAuth** — email auth, dashboard shell, and Lichess OmniAuth.

Prerequisite: [m0-manual-testing.md](m0-manual-testing.md) (app boots, Devise works).

Related docs:

- [make-commands.md](../development/make-commands.md)

**PRD checkpoint:** User can sign in and connect a Lichess account.

---

## Prerequisites

```bash
bin/rails db:seed               # optional: starship@example.com / skyd!ve
bin/dev
```

Configure Lichess OAuth in `.env` (see `.env.example`) for live OAuth tests. System specs use OmniAuth test mode; manual OAuth requires real credentials.

---

## 1. Automated suite (CI gate)

```bash
make test
```

M1-relevant specs:

- `spec/system/user_authentication_spec.rb`
- `spec/system/dashboard_spec.rb` (auth redirects, OAuth flows)
- `spec/requests/dashboard_spec.rb` (unauthenticated redirect)
- `spec/requests/users/omniauth_callbacks_spec.rb`
- `spec/services/provider_accounts/connect_lichess_spec.rb`
- `spec/lib/omniauth/strategies/lichess_spec.rb`

---

## 2. Email authentication

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | Visit `/` → **Sign up** | Registration form loads |
| 2.2 | Complete registration | Redirect to `/dashboard`; nav shows Dashboard, Settings, etc. |
| 2.3 | **Sign out** | Public home; `/dashboard` requires sign-in |
| 2.4 | **Sign in** with same credentials | Dashboard loads |
| 2.5 | Visit `/dashboard` while signed out | Redirect to `/users/sign_in` |

---

## 3. Dashboard shell (authenticated)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 3.1 | Sign in | Header: **Chess Mentor**, **Signed in as** username |
| 3.2 | Check left nav | Dashboard, Providers, Imports, Games, Weaknesses, Training |
| 3.3 | **Providers** card | Connect Lichess prompt (if not linked) |

---

## 4. Lichess OAuth — new user

Requires valid Lichess OAuth app credentials.

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | Sign out; visit Lichess OAuth entry (home or providers) | Redirect to Lichess authorize |
| 4.2 | Approve on Lichess | Redirect to `/dashboard` |
| 4.3 | Check dashboard / **Settings → Providers** | **Lichess connected as @username** |

---

## 5. Lichess OAuth — link while signed in

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | Sign in as user **without** Lichess | Providers shows connect prompt |
| 5.2 | **Connect Lichess** | OAuth flow; account linked without creating duplicate user |
| 5.3 | Refresh providers page | Connected username; **Disconnect** available |

---

## 6. OAuth error paths

| Step | Action | Expected |
| ---- | ------ | -------- |
| 6.1 | User A links Lichess; sign in as User B; attempt same Lichess account | Error: already linked to another user |
| 6.2 | Cancel or fail OAuth (deny on Lichess) | Redirect with alert; no orphan provider row |

---

## Minimum bar before merge

1. `make test` green
2. Email sign-up → dashboard → sign out → sign-in
3. Lichess OAuth creates or links account (live or verified via system specs in CI)
4. Unauthenticated `/dashboard` → sign-in redirect

---

## Automated test coverage map

| Scenario | Automated coverage | Spec / notes |
| -------- | ------------------- | ------------ |
| Email sign-up / sign-in / confirm | Yes | `spec/system/user_authentication_spec.rb` |
| Dashboard redirect after auth | Yes | `spec/system/dashboard_spec.rb` |
| OAuth new user | Yes | Request + system specs (test mode) |
| OAuth link while signed in | Yes | Service + request specs |
| Lichess conflict | Yes | Service + system specs |
| Live Lichess OAuth in browser | **No** | Manual with real credentials |
| Token encryption at rest | **No** | Deferred before production (todo) |

---

## Out of scope (M1)

- Game import (M3)
- Disconnect during active import (M3 — covered there)
- Chess.com OAuth
