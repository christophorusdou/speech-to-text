# Decisions & Lessons Learned

## Why a custom client instead of AudioWhisper?

AudioWhisper is a 25K-line app with issues on our setup:
- ATS (App Transport Security) blocked plain HTTP to the L40S server
- Keychain password prompts on every launch
- Complex codebase made debugging difficult

Our client is ~300 lines, does exactly what we need, and we control it entirely.

## macOS app signing and permissions

### The problem
A bare SPM executable (`swift build` output) can't get macOS microphone permission. Even if you grant it in System Settings, CoreAudio silently fails with `Could not find default device`.

### Why
macOS TCC (Transparency, Consent, and Control) ties permissions to **code-signed app bundles** identified by `CFBundleIdentifier`. A bare executable has no bundle identity, so macOS can't track its permissions.

### The fix
1. Wrap the binary in a `.app` bundle with `Info.plist` (containing `CFBundleIdentifier`)
2. Ad-hoc code sign: `codesign --force --deep --sign - SpeechToText.app`
3. Launch via `open SpeechToText.app` (not the binary directly)

Running the binary directly (`Contents/MacOS/SpeechToText`) bypasses the bundle identity and permissions fail again.

### Accessibility permission
Simulating Cmd+V paste via `CGEvent` requires Accessibility permission. This must be granted manually in System Settings > Privacy & Security > Accessibility. The app bundle must be listed there.

## Audio format: WAV not M4A

The speaches server (faster-whisper) rejected M4A files with HTTP 415. WAV (16-bit PCM, 16kHz, mono) works reliably and is what Whisper natively processes internally anyway. The files are larger but for short recordings (<30s) the size difference is negligible.

## Model comparison

Tested with real human speech (Open Speech Repository):

| Model | Time | Punctuation | Casing | Word accuracy |
|-------|------|-------------|--------|---------------|
| `deepdml/faster-whisper-large-v3-turbo-ct2` | 0.86s | none | lowercase | "park truck" (wrong) |
| `Systran/faster-whisper-large-v3` | 1.58s | full sentences | proper | "parked truck" (correct) |

The turbo model is a distilled version — faster but trades accuracy. Large-v3 is the same as OpenAI's whisper-large-v3, just in CTranslate2 format for faster-whisper.

### Language hint
Sending `language=en` with the request significantly improves accuracy. Without it, Whisper spends time on language detection and can make more errors.

### Model download
speaches doesn't auto-download models. Use the API:
```bash
curl -X POST http://localhost:8000/v1/models/Systran/faster-whisper-large-v3
```
Models are cached in a Docker volume (`hf-cache`).

## Credential management

### Pattern: macOS Keychain for all secrets

Never hardcode tokens in source, remote URLs, or config files. Use macOS Keychain:

```bash
# Store
security add-generic-password -s "<service>" -a "<account>" -w "<token>" -U

# Retrieve
security find-generic-password -s "<service>" -a "<account>" -w
```

### Git HTTPS credentials
`git config --global credential.helper osxkeychain` stores git credentials in Keychain. The `git-credential-osxkeychain` binary creates Keychain entries it can later read without prompting — macOS Keychain allows the creating binary silent access to its own entries.

### Forgejo API token
Stored in Keychain as service `forgejo-api`. Shell helper `forgejo-token` in `~/.zshenv`:
```bash
curl -H "Authorization: token $(forgejo-token)" https://git.cdrift.com/api/v1/...
```

## LLM post-processing with Ollama

### Why qwen3:8b?

Qwen 3 8B is a fast instruction-following model with strong text correction capabilities. At 8B parameters it loads quickly (~5GB VRAM), runs inference in <1 second, and auto-unloads after idle — coexisting well with Whisper on the L40S's 48GB VRAM.

### Graceful fallback design

LLM post-processing is entirely optional and fault-tolerant:
- Disabled by default (toggle in menu bar)
- 10-second timeout prevents stalls
- Any failure (network, timeout, bad response) silently falls back to the original Whisper text
- The gear icon (⚙) shows when LLM processing is active

### Vocabulary prompt vs LLM correction

Two complementary approaches:
- **Vocabulary prompt**: Biases Whisper's decoder at recognition time. Best for ambiguous terms where Whisper has multiple valid interpretations (e.g., "Claude" vs "cloud"). Limited to 224 tokens.
- **LLM correction**: Post-processes the text after Whisper. Catches genuine misrecognitions that the prompt can't fix (e.g., "clod code" → "Claude Code"). Adds ~0.5-1s latency.

Use both together for best results with technical vocabulary.

## TCC staleness on rebuild

### The problem

macOS TCC (Transparency, Consent, and Control) ties permissions to a code signature. Ad-hoc signing (`codesign --sign -`) generates a new signature every build. After rebuilding, the old TCC entry in System Settings still shows "enabled" but silently rejects the new binary. Paste via Cmd+V stops working with no error.

### The fix

Two-part solution in `bundle.sh` and `App.swift`:

1. **`bundle.sh`**: Runs `tccutil reset Accessibility com.cdrift.SpeechToText` after codesign. This clears the stale TCC entry so macOS doesn't silently reject the new signature.

2. **`App.swift`**: Calls `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true` on launch. This prompts the user to re-grant Accessibility if not currently trusted.

Without both, the user has to manually find and remove the app from System Settings > Privacy & Security > Accessibility, then re-add it.

## CI/CD with Forgejo Actions

### Why a Mac Mini runner?

Swift builds require macOS (Xcode CLI tools, codesign, Apple frameworks). The Mac Mini M4 runs a native Forgejo runner directly on the host (not containerized) with the `macos-arm64:host` label.

### upload-artifact@v3, not v4

`actions/upload-artifact@v4` uses GitHub's new artifact service API which detects Forgejo as GHES and refuses to run. `@v3` uses the older HTTP-based upload that Forgejo supports.

### Release via Forgejo API

Tagged pushes (`v*`) create releases via the Forgejo REST API and attach the zipped `.app` bundle. This uses a `RELEASE_TOKEN` secret (Forgejo API token with repo write scope).

### Sleep and CI timing

The Mac Mini sleeps 8pm–8am. Jobs queued during sleep are picked up when the runner reconnects at 8am. The runner uses launchd KeepAlive + ThrottleInterval for automatic restart.

## Push mirror (Forgejo → GitHub)

Configured via Forgejo API: sync on commit + every 8h. Same pattern as ticket-pointing repo. Delete branches from Forgejo (source), not GitHub — the mirror will re-push deleted branches if you only delete on the target.
