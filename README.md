# Speech-to-Text

System-wide speech-to-text on macOS using a remote L40S GPU server.

Hold Cmd+Shift+Space, speak, release — transcribed text appears at the cursor in any app.

## Architecture

```
Mac (SpeechToText.app)                     L40S Server
┌─────────────────┐                        ┌──────────────────────┐
│ Hold ⌘⇧Space    │                        │ speaches (port 8000) │
│ Record 16kHz WAV│──HTTP POST audio──────▶│ faster-whisper       │
│ Release hotkey   │◀──JSON {"text":"..."}──│ large-v3 model       │
│                 │                        ├──────────────────────┤
│ LLM correction  │──POST /v1/chat/───────▶│ ollama (port 11434)  │
│ (optional)      │◀──corrected text───────│ qwen3:8b           │
│                 │                        └──────────────────────┘
│ Clipboard + ⌘V  │
└─────────────────┘
```

## Components

- **Server**: [speaches](https://github.com/speaches-ai/speaches) — OpenAI API-compatible Whisper server with GPU acceleration
- **Server**: [Ollama](https://ollama.com) — local LLM for post-processing corrections (optional)
- **Client**: `client/` — Swift menu bar app (this repo)
- **Whisper models**: Selectable from menu bar
  - `Systran/faster-whisper-large-v3` — best accuracy, proper punctuation and casing (~1.5s)
  - `deepdml/faster-whisper-large-v3-turbo-ct2` — faster, less accurate (~0.8s)
- **LLM model**: `qwen3:8b` — fixes technical terms and jargon in transcription output

## Quick Start

### Server

```bash
ssh l40s
cd /shared/projects/speech-to-text/server
docker compose up -d

# Download Whisper models
curl -X POST http://localhost:8000/v1/models/Systran/faster-whisper-large-v3
curl -X POST http://localhost:8000/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2

# Download LLM for post-processing (optional, runs natively on host)
ollama pull qwen3:8b
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
