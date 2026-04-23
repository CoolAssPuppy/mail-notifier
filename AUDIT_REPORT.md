# Mail Notifier (macOS menu bar app) — Security, Reliability, and Refactoring Audit

## Scope and approach

This review focused on:

- Authentication and token lifecycle
- URL routing and deep-link handling
- Network/API error handling
- Persistence and notification correctness
- Concurrency/thread-safety issues
- AI-generated “slop” patterns (dead code, fragile assumptions, inconsistent style)

---

## Executive summary

Top issues to fix first:

1. **OAuth callback routing logic is too permissive** (potentially routes unexpected URLs to privileged handlers).
2. **Token refresh state is not persisted in provider state-change delegates** (can cause silent auth degradation).
3. **JWT parsing is unvalidated and non–base64url-safe** (identity extraction is brittle and trust boundary is unclear).
4. **Notification deduplication key can collide across providers/accounts** (missed notifications).
5. **Fetcher state updates are race-prone** (inconsistent auth/error state due to concurrent callbacks).

---

## High-priority security findings

### 1) Over-broad URL routing conditions (logic bug with security impact)

**Where:** `URLRouter.route(url:)`.

The `switch true` uses `case exprA, exprB` syntax, which is logical OR in Swift `switch` cases.
That means this branch will trigger if **either** `scheme == "mailnotifier"` **or** `host == "preferences"`, not both.

**Risk:** An attacker-controlled URL could accidentally hit privileged routes if one condition matches.

**Fix:** Replace with explicit boolean conjunctions:

```swift
if url.scheme == "mailnotifier" && url.host == "preferences" { ... }
```

Apply same explicit style to OAuth route matching for readability and safety.

---

### 2) JWT parsing without signature validation (trust boundary violation)

**Where:** `Accounts.decodeJWT(_:)` in authorization flow.

Current code manually decodes JWT payload and trusts claims for account email extraction. This is risky because:

- No signature verification.
- No issuer/audience/expiry checks.
- Decoding uses standard base64 decode but JWT payload is base64url.

**Risk:** Identity confusion and future exploitation if token source assumptions change.

**Fix options:**

- Preferred: Use claims from a trusted library/validated token source provided by AppAuth/MSAL-style helpers.
- If manual parsing remains, convert base64url (`-`/`_`) to base64, then verify signature + `iss`, `aud`, `exp`, `nonce/state` before trust.
- Avoid using unverified JWT claims as primary account identity.

---

### 3) OAuth callback acceptance should be stricter

**Where:** URL routing for Google/Outlook callbacks.

Routing checks are partial (`scheme + path` or `scheme + host`) and do not verify full redirect URI identity.

**Risk:** Easier to accidentally process malformed callback URLs and increases attack surface.

**Fix:** Compare normalized callback URL components against expected exact redirect URI pattern and reject extra/invalid forms before passing to `resumeAuthFlow`.

---

## High-priority correctness/reliability bugs

### 4) Token refresh updates are dropped (critical auth lifecycle bug)

**Where:** `GmailProvider.didChange(_:)` and `OutlookProvider.didChange(_:)`.

Both methods create a local `Account` and set updated auth state, but never persist back to `Accounts.default`.

**Impact:** Refreshed tokens/state may not persist, eventually causing reauth loops or unexpected auth failures.

**Fix:** Load account from store, update auth payload, and call `Accounts.default.update(account:)`.

---

### 5) Notification identifiers are not globally unique

**Where:** `NotificationService.deliverNotifications(for:)` uses `message.id` as identifier.

Message IDs may collide across providers/accounts.

**Impact:** New notifications may be suppressed or replaced incorrectly.

**Fix:** Build composite IDs, e.g. `"\(message.type.rawValue):\(message.email):\(message.id)"`.

---

### 6) Auth/error state race in fetch pipeline

**Where:** `MessageFetcher.fetch()` launches unread-count and message fetch in parallel and mutates shared flags independently.

**Impact:** A success in one callback can overwrite error state set by the other (or vice versa), causing inconsistent UI/security status.

**Fix:**

- Use a single async orchestration (`async let` + await both), then derive final state once.
- Centralize state mutation on `@MainActor`.

---

### 7) Google redirect scheme construction is fragile

**Where:** `GoogleOAuthClient.redirectURL` derives scheme from first segment of client ID; `Info.plist` contains hardcoded scheme.

**Impact:** Environment mismatch can break OAuth silently if plist/client config diverge.

**Fix:**

- Single source of truth via build setting/template-generated URL schemes.
- Startup assertion/logging for mismatch.

---

## Medium-priority security hardening

### 8) URL handler input constraints are minimal

**Where:** `handleGetURLEvent`, `handleMailTo`, and routing/compose code.

**Risk:** Very long or malformed `mailto` payloads can trigger memory/UX issues, and broad mailto handler role expands attack surface.

**Fix:**

- Enforce max URL length and max subject/recipient lengths.
- Reject control characters/newlines in recipient/subject.
- Consider whether app should register as global `mailto` handler.

---

### 9) Keychain accessibility/access-group policy is implicit

**Where:** `Account.keychain` uses default KeychainAccess configuration.

**Risk:** Security posture depends on defaults; policy is not explicit/auditable.

**Fix:** Explicitly set accessibility class and (if needed) access group policy. Example: `.accessibility(.whenUnlockedThisDeviceOnly)` for stricter local protection.

---

### 10) Sensitive data in logs

**Where:** keychain/archive errors include account IDs/emails in logs.

**Risk:** PII in unified logs.

**Fix:** Use privacy annotations/reduced identifiers in logs and avoid including raw email where unnecessary.

---

## Refactoring opportunities (reuse/readability)

### A) Unify provider abstractions with async API

Current callback-based APIs duplicate error mapping and state handling.

**Refactor:**

- Define async protocol methods (`fetchUnreadCount() async throws -> Int`, `fetchMessages(limit:) async throws -> [Message]`).
- Shared error mapper for HTTP/status/auth errors.
- Single fetch orchestrator in `MessageFetcher`.

### B) Centralize account persistence side effects

`Accounts.default.update` triggers notifications and storage writes; many call sites perform partial updates.

**Refactor:** Add an `AccountRepository` actor/service that owns mutation + persistence + event emission.

### C) Extract URL/deep-link validation layer

`URLRouter` should delegate to `DeepLinkValidator` with explicit typed routes.

### D) Make thread ownership explicit

`FetcherManager`, `MessageFetcher`, and notification fan-out should be main-actor isolated or actor-protected.

### E) Reduce duplication in OAuth clients

Google/Outlook clients share similar flow lifecycle code (authorize/resume/current flow).

**Refactor:** shared `OAuthFlowCoordinator` utility with provider-specific config.

---

## AI-generated code smell / “slop” indicators

1. **Dead/local-only updates** in provider `didChange` methods (suggests generated code missed persistence path).
2. **Mixed architectural styles** (callbacks + async/await + NotificationCenter as global bus).
3. **Inconsistent trust decisions** (manual JWT parsing in one place, library-driven auth elsewhere).
4. **Magic strings and duplicated URL-building logic** across app and model layers.
5. **Error flattening** (`authenticationRequired` used for non-auth failures in several paths), reducing diagnosability.

---

## macOS menu bar attack-surface checklist

- **Custom URL schemes:** strict parsing, exact-match redirect validation, reject unknown hosts/paths.
- **Default mailto handling:** avoid becoming implicit relay for hostile links without guardrails.
- **Notification actions:** ensure notification payload fields cannot trigger arbitrary URL opens.
- **Browser launching:** allowlist browser bundle IDs from installed apps only (already partially done) and fail closed.
- **Update channel:** Sparkle key pinning is present; ensure feed transport stays HTTPS and signatures remain required.
- **Local persistence:** minimize PII in defaults; keep tokens only in keychain with explicit policy.
- **Concurrency:** actor-isolate mutable state to prevent race-induced security-state confusion.

---

## Prioritized remediation plan

### Phase 1 (immediate)

1. Fix URL router condition logic (`&&` strict checks).
2. Persist refreshed auth state in provider delegates.
3. Replace/validate JWT claim extraction path.
4. Use globally unique notification identifiers.
5. Consolidate fetch result state updates to avoid races.

### Phase 2 (near-term hardening)

1. Add deep-link input size/content validation.
2. Make keychain accessibility explicit.
3. Improve error taxonomy and user-facing messaging.
4. Add structured tests for URL routing and auth-state persistence.

### Phase 3 (architecture cleanup)

1. Convert providers and fetcher to async/await end-to-end.
2. Introduce actor-backed repository/services for state ownership.
3. Consolidate OAuth flow management.

