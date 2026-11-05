# notchLLM adapters

## Gemini (critical — no login loop)

**Never login-loops.** Resolution order:

1. Live OAuth quota when local tokens exist  
   - `~/.gemini/jetski-standalone-oauth-token` (Antigravity)  
   - `~/.gemini/oauth_creds.json` (Gemini CLI)  
   - Access token is probed against Cloud Code; refresh only on 401 (env / local oauth-clients.json)  
   - `POST …/v1internal:retrieveUserQuotaSummary` (+ `retrieveUserQuota`, daily host)  
2. Local Gemini MacOS session  
   - `~/Library/Application Support/com.google.GeminiMacOS/account_config`  
   - `…/Data/<user>/auth` (non-empty)  
   - `~/.gemini/antigravity/antigravity_state.pbtxt`
3. API key: `GEMINI_API_KEY` / `GOOGLE_API_KEY` → Keychain service `notchLLM` account `gemini` → `~/Library/Application Support/notchLLM/credentials.json`
4. Manual tier caps in `~/Library/Application Support/notchLLM/settings.json`
5. Demo mock **only** when `preferMockWhenUnauthenticated: true` (default **false**)

Key validation (optional): `GET https://generativelanguage.googleapis.com/v1beta/models?pageSize=1`.  
Adapters never invent mid-range stub fractions for authenticated sessions. Unsigned-in cells show `–`.

## ChatGPT

- Codex CLI auth at `~/.codex/auth.json` (`tokens.access_token`, `account_id`) ⇒ signed in
- **Live:** `GET https://chatgpt.com/backend-api/wham/usage` (+ `cedar_ember` / `include_extra_usage` variants) with Bearer + `ChatGPT-Account-ID`  
  Uses the most constrained `rate_limit` window (`used_percent`); camelCase keys also accepted
- `OPENAI_API_KEY` validated via `GET https://api.openai.com/v1/models`
- Otherwise manual caps / optional demo mock

## Cursor

- Auth in `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Access tokens may be Electron `cursor-safe-storage:v1:` ciphertext — decrypted via Keychain `Cursor Safe Storage`
- **Live (preferred):**  
  - `POST https://cursor.com/api/dashboard/get-current-period-usage` with `WorkosCursorSessionToken=<userId>::<jwt>` + `Origin: https://cursor.com`  
  - `GET https://cursor.com/api/usage-summary`  
  - `GET https://api2.cursor.sh/auth/full_stripe_profile` / `auth/usage`  
  - Legacy bearer `/api/usage` + Connect dashboard fallbacks
- Falls back to membership default limit + **real** manual `windowUsed` (no invented %)

## Settings

**Entry points**
- Menu-bar status item → shows last refresh + auto-refresh interval → **Settings…** / **Refresh Usage** / **Quit notchLLM**
- Caps JSON: `~/Library/Application Support/notchLLM/settings.json`
- API keys: Keychain service `notchLLM` accounts `gemini` | `openai` | `cursor`
- `autoRefreshSeconds` (default `60`; `0` = off) — picker saves immediately; Settings also has **Refresh usage now**

```json
{
  "preferMockWhenUnauthenticated": false,
  "manualFallbackEnabled": true,
  "autoRefreshSeconds": 60,
  "providers": {
    "gemini": { "tier": "pro", "windowLimit": 1000000, "windowUsed": 0, "apiKeyHintPresent": false },
    "chatGPT": { "tier": "plus", "windowLimit": 100000, "windowUsed": 0, "apiKeyHintPresent": false },
    "cursor": { "tier": "pro", "windowLimit": 500, "windowUsed": 0, "apiKeyHintPresent": false }
  }
}
```

Saving settings posts `notchLLM.settingsDidChange` so rings refresh without restart.

## UI

CodeNotch-style slim right-edge capsule: ChatGPT → Cursor → Gemini, coral remaining rings, brand path icons, left tooltip with pointer. Spacing between cells (no hairline separators).

## Sandbox

App Sandbox is **off** so adapters can read sibling session files / Keychain safe-storage. Network client remains enabled for live usage.
