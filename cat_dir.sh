DIRECTORY=${1:-.}
for file in "$DIRECTORY"/*; do
    if [ -f "$file" ]; then
        echo "===== START OF FILE: $file ====="
        cat "$file"
        echo -e "\n===== END OF FILE: $file =====\n"
    fi
done
