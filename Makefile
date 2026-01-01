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
WHISPER_ARGS = -m $(MODEL) -l $(LANGUAGE) -t $(THREADS) -mc 0 -sow -ml 0 -otxt
else
WHISPER_CMD = $(WHISPER_SOURCE)
WHISPER_ARGS = -m $(MODEL) -l $(LANGUAGE) -t $(THREADS) -mc 0 -sow -ml 0 -otxt
endif

# Default input
INPUT ?= files/input.mp4

# Derived filenames
# Use shell commands to properly handle paths with spaces
BASENAME = $(shell f="$(INPUT)"; f=$$(basename "$$f"); echo "$${f%.*}")
WAV_FILE = files/$(BASENAME).wav
TXT_FILE = files/$(BASENAME).txt

.PHONY: all extract transcribe process process-dir clean help download-model

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
	@echo "  process-dir      - Process all MP4 files in directory (skips existing .txt)"
	@echo "  download-model   - Download whisper model from Hugging Face"
	@echo "  clean            - Remove generated WAV and TXT files"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make download-model MODEL_SIZE=large-v3"
	@echo "  make extract INPUT=files/video.mp4"
	@echo "  make transcribe INPUT=files/audio.wav"
	@echo "  make process INPUT=files/video.mp4"
	@echo "  make all INPUT=files/video.mp4"
	@echo "  make process-dir DIR=\"/path/to/videos\""
	@echo ""
	@echo "Configuration:"
	@echo "  MODEL_SIZE       - Model to download: tiny, base, small, medium, large-v3"
	@echo "  MODEL            - Whisper model file (default: $(MODEL))"
	@echo "  LANGUAGE         - Language code (default: $(LANGUAGE))"
	@echo "  THREADS          - Number of threads (default: $(THREADS))"
	@echo "  DIR              - Directory containing MP4 files for batch processing"
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
	@$(WHISPER_CMD) $(WHISPER_ARGS) -of "$(shell echo "$(TXT_FILE)" | sed 's/\.[^.]*$$//')" "$(WAV_FILE)"
	@echo "Transcription completed: $(TXT_FILE)"

# Extract and transcribe with custom input
process:
	@$(MAKE) extract INPUT="$(INPUT)"
	@$(MAKE) transcribe INPUT="$(INPUT)"

# Process all MP4 files in a directory, avoiding duplicates
process-dir:
	@if [ -z "$(DIR)" ]; then \
		echo "Error: DIR parameter is required"; \
		echo "Usage: make process-dir DIR=\"/path/to/videos\""; \
		exit 1; \
	fi
	@if [ ! -d "$(DIR)" ]; then \
		echo "Error: Directory not found: $(DIR)"; \
		exit 1; \
	fi
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
	@echo "Processing MP4 files in: $(DIR)"
	@echo "Checking for existing transcriptions and skipping duplicates..."
	@total=0; processed=0; skipped=0; \
	for mp4 in "$(DIR)"/*.mp4; do \
		if [ ! -f "$$mp4" ]; then continue; fi; \
		total=$$((total + 1)); \
		base=$$(basename "$$mp4" .mp4); \
		txt_file="$(DIR)/$$base.txt"; \
		if [ -f "$$txt_file" ]; then \
			echo "[SKIP] $$base (already transcribed)"; \
			skipped=$$((skipped + 1)); \
		else \
			echo ""; \
			echo "[$$processed/??] Processing: $$base"; \
			wav_file="files/$$base.wav"; \
			echo "  → Extracting audio..."; \
			ffmpeg -i "$$mp4" -ar 16000 -ac 1 -c:a pcm_s16le "$$wav_file" -y 2>&1 | grep -v "^frame=" || true; \
			echo "  → Transcribing..."; \
			$(WHISPER_CMD) $(WHISPER_ARGS) -of "$${wav_file%.wav}" "$$wav_file" 2>&1 | grep -E "(processing|whisper_|\.txt)" || true; \
			if [ -f "files/$$base.txt" ]; then \
				mv "files/$$base.txt" "$$txt_file"; \
				echo "  ✓ Transcription saved: $$txt_file"; \
			else \
				echo "  ✗ Error: Transcription file not created"; \
			fi; \
			rm -f "$$wav_file"; \
			processed=$$((processed + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	echo "Batch processing complete!"; \
	echo "Total files found: $$total"; \
	echo "Already transcribed (skipped): $$skipped"; \
	echo "Newly transcribed: $$processed"; \
	echo "========================================"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f files/*.wav files/*.txt
	@echo "Clean complete"
