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

## CI/CD

Forgejo Actions builds every push to `main` and every PR on the Mac Mini runner (native macOS ARM64):

- Builds and ad-hoc signs the `.app` bundle
- Uploads zipped artifact to the workflow run
- On tagged releases (`v*`): creates a Forgejo release with the zip attached

Workflow: [`.forgejo/workflows/build.yml`](.forgejo/workflows/build.yml)

To create a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Configuration

All settings via `defaults write com.cdrift.SpeechToText`:

| Key | Default | Description |
|-----|---------|-------------|
| `endpoint` | `http://localhost:8000` | Whisper server URL |
| `model` | `deepdml/faster-whisper-large-v3-turbo-ct2` | Whisper model (also selectable from menu) |
| `language` | `en` | Language hint for Whisper |
| `prompt` | _(empty)_ | Vocabulary prompt to bias recognition |
| `llmEnabled` | `false` | Enable LLM post-processing |
| `llmEndpoint` | `http://localhost:11434` | Ollama server URL |
| `llmModel` | `qwen3:8b` | Ollama model for corrections |

## Repository

- `server/` — speaches Docker Compose config
- `client/` — Swift menu bar app (SPM, single dependency: [HotKey](https://github.com/soffes/HotKey))
- `.forgejo/workflows/` — CI/CD workflow for macOS builds
- `docs/` — setup guide, decisions, troubleshooting
- Hosted on [Forgejo](https://git.cdrift.com/chris/speech-to-text), mirrored to [GitHub](https://github.com/christophorusdou/speech-to-text)
