# notchLLM adapters (Phase 3)

## Gemini (critical)

**Never login-loops.** Resolution order:

1. Local Gemini MacOS session  
   - `~/Library/Application Support/com.google.GeminiMacOS/account_config`  
   - `…/Data/<user>/auth` (non-empty)  
   - `~/.gemini/antigravity/antigravity_state.pbtxt`
2. API key: `GEMINI_API_KEY` / `GOOGLE_API_KEY` → Keychain service `notchLLM` account `gemini` → `~/Library/Application Support/notchLLM/credentials.json`
3. Manual tier caps in `~/Library/Application Support/notchLLM/settings.json`
4. Demo mock (default when `preferMockWhenUnauthenticated: true`)

Key validation (optional): `GET https://generativelanguage.googleapis.com/v1beta/models?pageSize=1`.  
Consumer “tokens remaining” is not a stable public API — rings use the **real** manual window (`windowUsed` / `windowLimit`) once authenticated. Adapters never invent mid-range stub fractions.

## ChatGPT

Assumptions:

- Codex CLI auth at `~/.codex/auth.json` (`tokens.access_token`, `account_id`) ⇒ signed in
- ChatGPT Atlas has no stable local usage ledger we read
- `OPENAI_API_KEY` validated via `GET https://api.openai.com/v1/models`
- Otherwise manual caps / mock

## Cursor

Assumptions:

- Auth in `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Safe keys: `cursorAuth/stripeMembershipType`, `stripeSubscriptionStatus`, `cachedEmail`
- Optional live (first success wins): `cursor.com/api/usage`, `www.cursor.com/api/usage`, `api2.cursor.sh/auth/usage` with Bearer access token (best-effort; shape may change)
- Falls back to membership default limit + **real** manual `windowUsed` (no invented %)

## Settings (Phase 4)

**Entry points**
- Menu-bar status item → **Settings…** / **Refresh Usage** / **Quit notchLLM**
- Caps JSON: `~/Library/Application Support/notchLLM/settings.json`
- API keys: Keychain service `notchLLM` accounts `gemini` | `openai` | `cursor`

```json
{
  "preferMockWhenUnauthenticated": true,
  "manualFallbackEnabled": true,
  "providers": {
    "gemini": { "tier": "pro", "windowLimit": 1000000, "windowUsed": 0, "apiKeyHintPresent": false },
    "chatGPT": { "tier": "plus", "windowLimit": 100000, "windowUsed": 0, "apiKeyHintPresent": false },
    "cursor": { "tier": "pro", "windowLimit": 500, "windowUsed": 0, "apiKeyHintPresent": false }
  }
}
```

Saving settings posts `notchLLM.settingsDidChange` so rings refresh without restart.

## Sandbox

App Sandbox is **off** so adapters can read sibling session files. Network client remains enabled for key probes / Cursor usage.
