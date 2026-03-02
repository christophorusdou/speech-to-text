# Setup Guide

## Server Setup (L40S)

### 1. Deploy speaches

```bash
ssh l40s
cd /shared/projects/speech-to-text/server
docker compose up -d
```

Check it's running:

```bash
docker compose logs -f
```

### 2. Download Whisper models

speaches doesn't auto-download models. Install via the API:

```bash
# Fast, slightly less accurate
curl -X POST http://localhost:8000/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2

# Full quality (recommended)
curl -X POST http://localhost:8000/v1/models/Systran/faster-whisper-large-v3
```

Each download is ~3GB. Models are cached in a Docker volume for persistence.

### 3. Set up Ollama (optional — for LLM post-processing)

Ollama runs natively on the L40S host (already installed, systemd service). Pull the correction model:

```bash
ssh l40s "ollama pull qwen3:8b"
```

Verify:

```bash
curl http://<server-ip>:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:8b","messages":[{"role":"user","content":"Fix: clod code"}]}'
```

The model uses ~5GB VRAM when loaded and auto-unloads after idle. With ~42GB free on the L40S, this coexists fine with Whisper.

Note: Ollama must listen on `0.0.0.0` (not just localhost) for remote access. Set `OLLAMA_HOST=0.0.0.0` in `/etc/systemd/system/ollama.service` under `[Service]`.

### 4. Verify Whisper server

```bash
curl http://localhost:8000/v1/audio/transcriptions \
  -F file=@test.wav \
  -F model=Systran/faster-whisper-large-v3 \
  -F language=en
```

## Client Setup (Mac)

### 1. Build the client

```bash
cd client
./bundle.sh
```

### 2. Configure endpoint

```bash
defaults write com.cdrift.SpeechToText endpoint "http://<server-ip>:8000"
```

### 3. Launch

```bash
open .build/SpeechToText.app
```

### 4. Grant permissions

When prompted, allow:
- **Microphone** — for audio recording
- **Accessibility** — for simulating Cmd+V paste (System Settings > Privacy & Security > Accessibility)

### 5. Test

1. Open any text field
2. Hold Cmd+Shift+Space, speak, release
3. Text should appear at cursor

### 6. Select model

Click the menu bar icon > Model > choose between turbo (faster) and large-v3 (more accurate).

### 7. Configure vocabulary prompt (optional)

Click "Edit Vocabulary..." in the menu bar to add terms Whisper often misrecognizes. This biases the decoder toward your vocabulary (e.g., "Claude Code, Terraform, Kubernetes").

### 8. Enable LLM post-processing (optional)

Toggle "LLM Post-Processing" in the menu bar. Requires Ollama running on the server (step 3).

Configure the LLM endpoint if it differs from the default:

```bash
defaults write com.cdrift.SpeechToText llmEndpoint "http://<server-ip>:11434"
defaults write com.cdrift.SpeechToText llmModel "qwen3:8b"
```

When enabled, transcriptions are sent through the LLM to fix technical terms before pasting. If the LLM is unreachable, the original transcription is used.

## Git Credentials (Forgejo)

The Forgejo API token is stored in the macOS Keychain, not in any file or remote URL.

### How it works

1. `git config --global credential.helper osxkeychain` tells git to delegate credential storage to `git-credential-osxkeychain`
2. When git needs credentials for `https://git.cdrift.com`, the helper queries Keychain for a matching entry (protocol + host)
3. No Keychain prompt because `git-credential-osxkeychain` is the "owner" of the entry it created — macOS Keychain allows the creating binary to access its own items silently

### Store a token

```bash
printf "protocol=https\nhost=git.cdrift.com\nusername=chris\npassword=<token>\n" | git credential-osxkeychain store
```

### Verify it's stored

```bash
printf "protocol=https\nhost=git.cdrift.com\n" | git credential-osxkeychain get
```

### Revoke/update

```bash
# Remove from Keychain
printf "protocol=https\nhost=git.cdrift.com\n" | git credential-osxkeychain erase

# Store new token
printf "protocol=https\nhost=git.cdrift.com\nusername=chris\npassword=<new-token>\n" | git credential-osxkeychain store
```

### Why no permission prompt?

macOS Keychain uses per-item access control lists (ACLs). When `git-credential-osxkeychain store` creates an entry, that binary is added to the ACL as an allowed accessor. On subsequent reads, Keychain checks if the requesting binary matches — same binary path and code signature means silent access. A different app trying to read the same entry would trigger a Keychain prompt.

You can inspect this in Keychain Access.app: find the `git.cdrift.com` entry > Get Info > Access Control.

## Troubleshooting

- **No response**: Check server is running: `ssh l40s "docker ps | grep speaches"`
- **Slow first request**: Model loads on first inference, subsequent requests are fast
- **Permission errors**: Check System Settings > Privacy & Security on Mac
- **Empty recordings (4KB WAV)**: Microphone permission not granted, or app not code-signed — rebuild with `./bundle.sh`
- **"Could not find default device"**: Relaunch via `open .build/SpeechToText.app` (not the binary directly)

## Security Notes

Port 8000 on L40S is open without authentication. This is a shared server — the speaches endpoint only does transcription (no sensitive data stored). Consider adding an SSH tunnel for additional security:

```bash
ssh -L 8000:localhost:8000 l40s
# Then use http://localhost:8000 as endpoint
```
