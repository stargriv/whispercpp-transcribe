# Makefile for video transcription using whisper-cpp

# Configuration
MODEL = models/ggml-large-v3.bin
LANGUAGE = ru
THREADS = 4

# Auto-detect whisper installation
# First check if installed via brew (whisper-cli), otherwise use source build
WHISPER_BREW := $(shell which whisper-cli 2>/dev/null)
WHISPER_CPP_PATH ?= ../whisper.cpp
WHISPER_SOURCE := $(WHISPER_CPP_PATH)/main

ifneq ($(WHISPER_BREW),)
WHISPER_CMD = whisper-cli
WHISPER_ARGS = -m $(MODEL) -l $(LANGUAGE) -t $(THREADS) -mc 0 -sow -ml 0 -otxt -of $(basename $(TXT_FILE))
else
WHISPER_CMD = $(WHISPER_SOURCE)
WHISPER_ARGS = -m $(MODEL) -l $(LANGUAGE) -t $(THREADS) -mc 0 -sow -ml 0 -otxt -of $(basename $(TXT_FILE))
endif

# Default input
INPUT ?= files/input.mp4

# Derived filenames
BASENAME = $(basename $(notdir $(INPUT)))
WAV_FILE = files/$(BASENAME).wav
TXT_FILE = files/$(BASENAME).txt

.PHONY: all extract transcribe process clean help download-model

# Default target - show help
help:
	@echo "Video Transcription with Whisper.cpp - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  help             - Show this help message (default)"
	@echo "  all              - Extract audio and transcribe"
	@echo "  extract          - Extract audio from MP4 to WAV"
	@echo "  transcribe       - Transcribe WAV to text using whisper-cpp"
	@echo "  process          - Process specific file (extract + transcribe)"
	@echo "  download-model   - Download whisper model from Hugging Face"
	@echo "  clean            - Remove generated WAV and TXT files"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make download-model MODEL_SIZE=large-v3"
	@echo "  make extract INPUT=files/video.mp4"
	@echo "  make transcribe INPUT=files/audio.wav"
	@echo "  make process INPUT=files/video.mp4"
	@echo "  make all INPUT=files/video.mp4"
	@echo ""
	@echo "Configuration:"
	@echo "  MODEL_SIZE       - Model to download: tiny, base, small, medium, large-v3"
	@echo "  MODEL            - Whisper model file (default: $(MODEL))"
	@echo "  LANGUAGE         - Language code (default: $(LANGUAGE))"
	@echo "  THREADS          - Number of threads (default: $(THREADS))"
	@echo ""
	@echo "Whisper installation: $(if $(WHISPER_BREW),Homebrew ($(WHISPER_BREW)),Source build or not found)"

# Extract and transcribe
all: extract transcribe

# Download a whisper model from Hugging Face
# Usage: make download-model MODEL_SIZE=large-v3
download-model:
	@MODEL_SIZE=$${MODEL_SIZE:-large-v3}; \
	echo "Downloading ggml-$$MODEL_SIZE.bin model from Hugging Face..."; \
	mkdir -p models; \
	curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$$MODEL_SIZE.bin" \
		-o "models/ggml-$$MODEL_SIZE.bin" --progress-bar; \
	echo "Model downloaded to models/ggml-$$MODEL_SIZE.bin"

# Extract audio from MP4 to WAV (16kHz, mono, compatible with whisper-cpp)
extract:
	@echo "Extracting audio from $(INPUT) to $(WAV_FILE)..."
	@ffmpeg -i "$(INPUT)" -ar 16000 -ac 1 -c:a pcm_s16le "$(WAV_FILE)" -y
	@echo "Audio extracted successfully to $(WAV_FILE)"

# Transcribe WAV file to text using whisper-cli or whisper.cpp
transcribe:
	@echo "Transcribing $(WAV_FILE) to text..."
	@if [ -z "$(WHISPER_BREW)" ] && [ ! -f "$(WHISPER_CMD)" ]; then \
		echo "Error: whisper-cli not found"; \
		echo "Install with: brew install whisper-cpp"; \
		echo "Or build from source and set WHISPER_CPP_PATH"; \
		exit 1; \
	fi
	@if [ ! -f "$(MODEL)" ]; then \
		echo "Error: Model not found at $(MODEL)"; \
		echo "Download with: make download-model MODEL_SIZE=large-v3"; \
		exit 1; \
	fi
	@$(WHISPER_CMD) $(WHISPER_ARGS) "$(WAV_FILE)"
	@echo "Transcription completed: $(TXT_FILE)"

# Extract and transcribe with custom input
process:
	@$(MAKE) extract INPUT="$(INPUT)"
	@$(MAKE) transcribe INPUT="$(INPUT)"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f files/*.wav files/*.txt
	@echo "Clean complete"
