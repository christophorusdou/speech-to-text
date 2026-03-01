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

### 2. Download the model

speaches doesn't auto-download models. Install it via the API:

```bash
curl -X POST http://localhost:8000/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2
```

This downloads ~3GB. The model is cached in a Docker volume for persistence.

### 3. Verify server

```bash
curl http://localhost:8000/v1/audio/transcriptions \
  -F file=@test.wav \
  -F model=deepdml/faster-whisper-large-v3-turbo-ct2
```

Or from Mac:

```bash
curl http://150.1.8.167:8000/v1/audio/transcriptions \
  -F file=@test.wav \
  -F model=deepdml/faster-whisper-large-v3-turbo-ct2
```

## Client Setup (Mac)

### 1. Install AudioWhisper

```bash
brew tap mazdak/tap && brew install audiowhisper
```

### 2. Grant permissions

When prompted, allow:
- **Microphone** access
- **Input Monitoring** (for global hotkey)
- **Accessibility** (for text pasting)

### 3. Configure

Open AudioWhisper from the menu bar:

| Setting | Value |
|---------|-------|
| Engine | OpenAI |
| Custom endpoint | `http://150.1.8.167:8000` |
| API key | `placeholder` (any non-empty string) |
| Model | `deepdml/faster-whisper-large-v3-turbo-ct2` |
| Express Mode | Enabled |
| Hotkey | Your preference (default: Fn hold-to-talk) |

### 4. Test

1. Open any text field
2. Hold hotkey, speak "hello world", release
3. Text should appear at cursor

## Troubleshooting

- **No response**: Check server is running: `ssh l40s "docker ps | grep speaches"`
- **Slow first request**: Model loads on first inference, subsequent requests are fast
- **Permission errors**: Check System Settings > Privacy & Security on Mac
- **Network timeout**: Verify connectivity: `curl http://150.1.8.167:8000/health`

## Security Notes

Port 8000 on L40S is open without authentication. This is a shared server — the speaches endpoint only does transcription (no sensitive data stored). Consider adding an SSH tunnel for additional security:

```bash
ssh -L 8000:localhost:8000 l40s
# Then use http://localhost:8000 as endpoint
```
