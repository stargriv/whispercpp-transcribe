# Video Transcription with Whisper.cpp

This project extracts audio from MP4 video files and transcribes them to text using whisper-cpp. Supports multiple languages including Russian.

## Prerequisites

- **ffmpeg**: For audio extraction from video files
  ```bash
  brew install ffmpeg  # macOS
  ```

- **whisper.cpp**: For speech-to-text transcription

  Option 1 - Install via Homebrew (recommended):
  ```bash
  brew install whisper-cpp
  ```
  This installs the `whisper-cli` command.

  Option 2 - Build from source:
  ```bash
  git clone https://github.com/ggerganov/whisper.cpp.git
  cd whisper.cpp
  make
  ```
  This creates the `main` executable in the whisper.cpp directory.

## Models

Whisper models need to be in **GGML format** (`.bin` files) to work with whisper-cpp.

### Download from Hugging Face

You can download pre-converted GGML models from Hugging Face:

**Quick Download via Makefile (recommended):**
```bash
# Download large-v3 model (~3GB)
make download-model MODEL_SIZE=large-v3

# Download other models
make download-model MODEL_SIZE=small    # ~466 MB
make download-model MODEL_SIZE=medium   # ~1.5 GB
```

**Manual Download:**
- Repository: https://huggingface.co/ggerganov/whisper.cpp
- Direct download example (large-v3):
  ```bash
  # Create models directory if it doesn't exist
  mkdir -p models

  # Download large-v3 model (~3GB)
  curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin \
    -o models/ggml-large-v3.bin
  ```

### Available Model Sizes

| Model | Size | Download URL |
|-------|------|--------------|
| tiny | ~75 MB | `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin` |
| base | ~142 MB | `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin` |
| small | ~466 MB | `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin` |
| medium | ~1.5 GB | `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin` |
| large-v3 | ~3 GB | `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin` |

**Recommendations:**
- **tiny/base**: Fast, lower accuracy - good for testing
- **small**: Good balance of speed and accuracy
- **medium**: Better accuracy, slower processing
- **large-v3**: Best accuracy, slowest (currently in use)

### Model Format

- **Format**: GGML (Binary format)
- **File extension**: `.bin`
- **Compatibility**: Must be GGML format, not PyTorch (`.pt`) or SafeTensors
- **Note**: Newer whisper.cpp versions support GGUF format (`.gguf`), but GGML `.bin` files still work

## Directory Structure

```
.
├── files/          # Directory for input MP4 files and output WAV/TXT files
├── models/         # Directory for Whisper models (e.g., ggml-large-v3.bin)
├── Makefile        # Automation scripts
└── README.md       # This file
```

## Usage

### Extract Audio from MP4

To extract audio from an MP4 file to WAV format (16kHz, mono - compatible with whisper-cpp):

```bash
make extract INPUT=files/your-video.mp4
```

The Makefile derives output names automatically based on the input basename (e.g., `files/your-video.wav`).

### Transcribe Audio to Text

To transcribe a WAV file to text using Russian language:

```bash
make transcribe INPUT=files/output.wav
```

This will create `files/output.txt` (same basename, `.txt` extension) with the transcription.

### Complete Pipeline

To extract audio and transcribe in one command:

```bash
make all INPUT=files/your-video.mp4
```

This will:
1. Extract audio to `files/your-video.wav`
2. Transcribe to `files/your-video.txt`

You can also run the same two-step flow explicitly via `make process INPUT=files/your-video.mp4`.

### Clean Output Files

To remove all generated WAV and TXT files:

```bash
make clean
```

## Configuration

Edit the `Makefile` to configure:
- `MODEL`: Whisper model to use (default: `models/ggml-large-v3.bin`)
- `LANGUAGE`: Language for transcription (default: `ru` for Russian)
- `THREADS`: Number of CPU threads to use (default: `4`)
- `WHISPER_CPP_PATH`: Path to source build (default: `../whisper.cpp`)
- `INPUT`: Default input file when not provided (default: `files/input.mp4`)

### Whisper-CLI Parameters Used

The Makefile uses the following whisper-cli parameters:
- `-m` / `--model`: Path to the GGML model file
- `-l` / `--language`: Language code (`ru` for Russian, `en` for English, etc.)
- `-t` / `--threads`: Number of threads for computation
- `-mc 0`: Disable max-context truncation
- `-sow`: Enable start-of-word timestamps
- `-ml 0`: Disable max-segment-length truncation
- `-otxt` / `--output-txt`: Generate text output file
- `-of` / `--output-file`: Output file path (without extension)

For more options, run: `whisper-cli --help`

## Notes

- The audio is extracted at **16kHz mono WAV format**, which is the standard input for whisper.cpp
- The **large-v3 model** provides the highest accuracy but requires more processing time
- Transcription output is saved as plain text files (`.txt`)
- The Makefile automatically detects whether you're using `whisper-cli` (Homebrew) or source build
