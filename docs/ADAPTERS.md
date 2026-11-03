# notchLLM adapters

## Gemini (critical — no login loop)

**Never login-loops.** Resolution order:

1. Live OAuth quota when local tokens exist  
   - `~/.gemini/jetski-standalone-oauth-token` (Antigravity)  
   - `~/.gemini/oauth_creds.json` (Gemini CLI)  
   - Uses a still-valid access token as-is (no login)  
   - Optional refresh via env (`NOTCHLLM_ANTIGRAVITY_CLIENT_ID/SECRET`, `NOTCHLLM_GEMINI_CLI_CLIENT_ID/SECRET`) or `~/Library/Application Support/notchLLM/oauth-clients.json`  
   - `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary` (and `retrieveUserQuota`)
2. Local Gemini MacOS session  
   - `~/Library/Application Support/com.google.GeminiMacOS/account_config`  
   - `…/Data/<user>/auth` (non-empty)  
   - `~/.gemini/antigravity/antigravity_state.pbtxt`
3. API key: `GEMINI_API_KEY` / `GOOGLE_API_KEY` → Keychain service `notchLLM` account `gemini` → `~/Library/Application Support/notchLLM/credentials.json`
4. Manual tier caps in `~/Library/Application Support/notchLLM/settings.json`
5. Demo mock (default when `preferMockWhenUnauthenticated: true`)

Key validation (optional): `GET https://generativelanguage.googleapis.com/v1beta/models?pageSize=1`.  
Adapters never invent mid-range stub fractions for authenticated sessions.

## ChatGPT

- Codex CLI auth at `~/.codex/auth.json` (`tokens.access_token`, `account_id`) ⇒ signed in
- **Live:** `GET https://chatgpt.com/backend-api/wham/usage` with Bearer + `ChatGPT-Account-ID`  
  Uses the most constrained `rate_limit` window (`used_percent`)
- `OPENAI_API_KEY` validated via `GET https://api.openai.com/v1/models`
- Otherwise manual caps / mock

## Cursor

- Auth in `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Access tokens may be Electron `cursor-safe-storage:v1:` ciphertext — decrypted via Keychain `Cursor Safe Storage`
- **Live (preferred):**  
  - `POST https://cursor.com/api/dashboard/get-current-period-usage` with `WorkosCursorSessionToken=<userId>::<jwt>` + `Origin: https://cursor.com`  
  - `GET https://cursor.com/api/usage-summary`  
  - Legacy bearer `/api/usage` fallbacks
- Falls back to membership default limit + **real** manual `windowUsed` (no invented %)

## Settings

**Entry points**
- Menu-bar status item → **Settings…** / **Refresh Usage** / **Quit notchLLM**
- Caps JSON: `~/Library/Application Support/notchLLM/settings.json`
- API keys: Keychain service `notchLLM` accounts `gemini` | `openai` | `cursor`
- `autoRefreshSeconds` (default `60`; `0` = off) schedules live polling while the app runs

```json
{
  "preferMockWhenUnauthenticated": true,
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

CodeNotch-style slim right-edge capsule: ChatGPT → Cursor → Gemini, coral remaining rings, brand path icons, left tooltip with pointer.

## Sandbox

App Sandbox is **off** so adapters can read sibling session files / Keychain safe-storage. Network client remains enabled for live usage.
