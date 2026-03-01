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

### 2. Download models

speaches doesn't auto-download models. Install via the API:

```bash
# Fast, slightly less accurate
curl -X POST http://localhost:8000/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2

# Full quality (recommended)
curl -X POST http://localhost:8000/v1/models/Systran/faster-whisper-large-v3
```

Each download is ~3GB. Models are cached in a Docker volume for persistence.

### 3. Verify server

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
