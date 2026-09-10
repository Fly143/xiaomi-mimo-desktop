# mimo-login-bypass

Patch Xiaomi MiMo Desktop (`app.asar`) so the app skips the startup login wall and opens the main UI directly.

**Scope:** UI gate only. Server-side model APIs still require a valid account / API key.

## Files

| File | Role |
|------|------|
| `patch-mimo-login-bypass.ps1` | In-place equal-length patch of `START_AUTH_BYPASS` |
| `patch-mimo-login-bypass.cmd` | Double-click wrapper (UAC elevate + run + restart) |

No proprietary binaries (`app.asar` / installer) are committed.

## What it changes

In `resources/app.asar` → `out/main/domain-BDBOtQLW.mjs`:

```js
// before
z = process.env.MIMO_START_AUTH_BYPASS === "1" && process.defaultApp === !0 && !R

// after
z = !0
```

Propagation:

```
domain START_AUTH_BYPASS
  → main process.env.MIMO_START_AUTH_BYPASS_RESOLVED = "1"
  → preload window.mimo.authBypass = true
  → renderer gate k4e(..., HR()) === "authenticated"
  → main UI, no login page
```

## Usage (after each app update)

Run as **Administrator**:

```powershell
powershell -ExecutionPolicy Bypass -File .\patch-mimo-login-bypass.ps1 -Start
```

Or double-click `patch-mimo-login-bypass.cmd`.

Default target:

```
C:\Program Files\Xiaomi MiMo\resources\app.asar
```

Options:

```powershell
-Asar <path>   # custom install path
-Start         # launch app after patch
-Force         # refresh .bak backup
```

## Behavior

- Idempotent: already patched → no-op
- One exact match required; layout change → abort (no blind write)
- Same-length rewrite (spaces pad `z=!0`), file size unchanged
- Backup: `app.asar.bak` next to the original (created once unless `-Force`)

## Rollback

```powershell
Copy-Item "C:\Program Files\Xiaomi MiMo\resources\app.asar.bak" `
          "C:\Program Files\Xiaomi MiMo\resources\app.asar" -Force
```

## Notes

- Auto-update overwrites `app.asar`; re-run the script after updates.
- The app process must be stopped first (script does this).
- For local / research use on a machine you control.
