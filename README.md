# Speech-to-Text

System-wide speech-to-text on macOS using a remote L40S GPU server.

Hold Cmd+Shift+Space, speak, release — transcribed text appears at the cursor in any app.

## Architecture

```
Mac (SpeechToText.app)                     L40S Server (speaches)
┌─────────────────┐                        ┌──────────────────────┐
│ Hold ⌘⇧Space    │                        │ Docker container     │
│ Record 16kHz WAV│──HTTP POST audio──────▶│ speaches (port 8000) │
│ Release hotkey   │◀──JSON {"text":"..."}──│ faster-whisper       │
│ Clipboard + ⌘V  │                        │ large-v3 model       │
└─────────────────┘                        └──────────────────────┘
```

## Components

- **Server**: [speaches](https://github.com/speaches-ai/speaches) — OpenAI API-compatible Whisper server with GPU acceleration
- **Client**: `client/` — ~300 line Swift menu bar app (this repo)
- **Models**: Selectable from menu bar
  - `Systran/faster-whisper-large-v3` — best accuracy, proper punctuation and casing (~1.5s)
  - `deepdml/faster-whisper-large-v3-turbo-ct2` — faster, less accurate (~0.8s)

## Quick Start

### Server

```bash
ssh l40s
cd /shared/projects/speech-to-text/server
docker compose up -d

# Download models
curl -X POST http://localhost:8000/v1/models/Systran/faster-whisper-large-v3
curl -X POST http://localhost:8000/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2
```

### Client

```bash
cd client

# Build and code-sign
./bundle.sh

# Set your server endpoint
defaults write com.cdrift.SpeechToText endpoint "http://<server-ip>:8000"

# Launch
open .build/SpeechToText.app
```

Grant Microphone and Accessibility permissions when prompted.

See [docs/setup.md](docs/setup.md) for detailed instructions.

## Repository

- `server/` — speaches Docker Compose config
- `client/` — Swift menu bar app (SPM, single dependency: [HotKey](https://github.com/soffes/HotKey))
- `docs/` — setup guide, decisions, troubleshooting
- Hosted on [Forgejo](https://git.cdrift.com/chris/speech-to-text), mirrored to [GitHub](https://github.com/christophorusdou/speech-to-text)
