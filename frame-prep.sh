#!/bin/bash
# ============================================================
# Frame Preparation Script for Scroll-Scrub Heroes
# ============================================================
# Extracts frames from video/GIF, optimizes them, and optionally
# uploads to WordPress Media Library via REST API.
#
# Usage:
#   ./frame-prep.sh <input_file> [options]
#
# Options:
#   --fps 15          Target frame rate (default: 15)
#   --width 1920      Max width in pixels (default: 1920)
#   --quality 80      JPEG quality 1-100 (default: 80)
#   --output ./frames Output directory (default: ./frames)
#   --upload          Upload to WordPress after processing
#   --wp-url URL      WordPress site URL (required for --upload)
#   --wp-user USER    WordPress username (required for --upload)
#   --wp-pass PASS    Application Password (required for --upload)
# ============================================================

set -e

# Defaults
FPS=15
WIDTH=1920
QUALITY=80
OUTPUT_DIR="./frames"
UPLOAD=false
WP_URL=""
WP_USER=""
WP_PASS=""

INPUT_FILE="$1"
shift || true

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --fps) FPS="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    --quality) QUALITY="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --upload) UPLOAD=true; shift ;;
    --wp-url) WP_URL="$2"; shift 2 ;;
    --wp-user) WP_USER="$2"; shift 2 ;;
    --wp-pass) WP_PASS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$INPUT_FILE" ]; then
  echo "Usage: $0 <input_file> [options]"
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file not found: $INPUT_FILE"
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Detect input type
EXT="${INPUT_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

echo "=== Frame Preparation ==="
echo "Input: $INPUT_FILE"
echo "Output: $OUTPUT_DIR"
echo "FPS: $FPS | Width: $WIDTH | Quality: $QUALITY"
echo ""

# Extract frames based on input type
case "$EXT_LOWER" in
  mp4|mov|avi|webm|mkv)
    echo "Extracting frames from video at ${FPS}fps..."
    ffmpeg -i "$INPUT_FILE" \
      -vf "fps=$FPS,scale=$WIDTH:-1:flags=lanczos" \
      -q:v 2 \
      "$OUTPUT_DIR/frame-%03d.jpg" \
      -y -loglevel warning
    ;;
  gif)
    echo "Extracting frames from GIF..."
    # First extract as PNG (lossless), then convert to optimized JPG
    ffmpeg -i "$INPUT_FILE" \
      -vf "scale=$WIDTH:-1:flags=lanczos" \
      "$OUTPUT_DIR/frame-%03d.png" \
      -y -loglevel warning

    echo "Converting PNG frames to optimized JPG..."
    for f in "$OUTPUT_DIR"/frame-*.png; do
      base=$(basename "$f" .png)
      convert "$f" -quality "$QUALITY" -strip "$OUTPUT_DIR/${base}.jpg"
      rm "$f"
    done
    ;;
  *)
    echo "Error: Unsupported format: $EXT_LOWER"
    echo "Supported: mp4, mov, avi, webm, mkv, gif"
    exit 1
    ;;
esac

# Optimize JPG frames
echo ""
echo "Optimizing frames..."
FRAME_COUNT=0
for f in "$OUTPUT_DIR"/frame-*.jpg; do
  if [ -f "$f" ]; then
    # Resize if wider than target (maintains aspect ratio)
    convert "$f" -resize "${WIDTH}>" -quality "$QUALITY" -strip "$f"
    FRAME_COUNT=$((FRAME_COUNT + 1))
  fi
done

echo "Total frames: $FRAME_COUNT"
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "Total size: $TOTAL_SIZE"

# Upload to WordPress if requested
if [ "$UPLOAD" = true ]; then
  if [ -z "$WP_URL" ] || [ -z "$WP_USER" ] || [ -z "$WP_PASS" ]; then
    echo ""
    echo "Error: --upload requires --wp-url, --wp-user, and --wp-pass"
    exit 1
  fi

  echo ""
  echo "Uploading $FRAME_COUNT frames to WordPress..."
  echo "Target: $WP_URL/wp-json/wp/v2/media"
  echo ""

  UPLOADED=0
  for f in "$OUTPUT_DIR"/frame-*.jpg; do
    FILENAME=$(basename "$f")
    RESPONSE=$(curl -s -u "$WP_USER:$WP_PASS" \
      -F "file=@$f" \
      "$WP_URL/wp-json/wp/v2/media")

    URL=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source_url','ERROR'))" 2>/dev/null)

    if [ "$URL" != "ERROR" ]; then
      UPLOADED=$((UPLOADED + 1))
      echo "  [$UPLOADED/$FRAME_COUNT] $FILENAME -> $URL"
    else
      echo "  FAILED: $FILENAME"
      echo "  Response: $(echo "$RESPONSE" | head -c 200)"
    fi
  done

  echo ""
  echo "Upload complete: $UPLOADED/$FRAME_COUNT frames uploaded."
fi

echo ""
echo "=== Done ==="
echo "Frames ready at: $OUTPUT_DIR/"
echo "Frame naming pattern: frame-001.jpg through frame-$(printf '%03d' $FRAME_COUNT).jpg"
