# Speech-to-Text

System-wide speech-to-text on macOS using a remote L40S GPU server.

Hold a hotkey, speak, release — transcribed text appears at the cursor in any app.

## Architecture

```
Mac (AudioWhisper)                         L40S Server (speaches)
┌─────────────────┐                        ┌──────────────────────┐
│ Hold hotkey      │                        │ Docker container     │
│ Record audio     │──HTTP POST audio──────▶│ speaches (port 8000) │
│ Release hotkey   │◀──JSON text response───│ faster-whisper       │
│ ⌘V paste text   │                        │ large-v3-turbo model │
└─────────────────┘                        └──────────────────────┘
```

## Components

- **Server**: [speaches](https://github.com/speaches-ai/speaches) — OpenAI API-compatible Whisper server with GPU acceleration
- **Client**: [AudioWhisper](https://github.com/mazdak/AudioWhisper) — native macOS menu bar app
- **Model**: `Systran/faster-whisper-large-v3-turbo` — 4x faster than original Whisper, ~6GB VRAM

## Quick Start

### Server (L40S)

```bash
ssh l40s
cd /shared/projects/speech-to-text/server
docker compose up -d
```

### Client (Mac)

```bash
brew install audiowhisper
```

Configure AudioWhisper:
- Engine: **OpenAI**
- Endpoint: `http://150.1.8.167:8000`
- API key: any non-empty string
- Model: `Systran/faster-whisper-large-v3-turbo`
- Enable **Express Mode** for auto-paste

See [docs/setup.md](docs/setup.md) for detailed instructions.
