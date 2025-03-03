#!/bin/bash

# Ensure the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 input_video target_frame_rate"
    exit 1
fi

input_video="$1"
target_frame_rate="$2"

# Extract the directory, filename without extension, and extension
input_dir=$(dirname "$input_video")
input_filename=$(basename "$input_video")
input_extension="${input_filename##*.}"
input_basename="${input_filename%.*}"

# Create a temporary output file with the same extension
temp_output=$(mktemp "${input_dir}/${input_basename}_temp.XXXXXX.${input_extension}")

# Use FFmpeg to change the frame rate
ffmpeg -i "$input_video" -r "$target_frame_rate" -c:v libx264 -preset slow -crf 22 -c:a copy -y "$temp_output"

# Check if FFmpeg command was successful
if [ $? -eq 0 ]; then
    mv -f "$temp_output" "$input_video"
    echo "Frame rate of '$input_video' has been successfully changed to $target_frame_rate fps."
else
    echo "An error occurred during the frame rate conversion."
    rm -f "$temp_output"
    exit 1
fi