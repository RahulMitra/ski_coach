#!/usr/bin/env bash

# Define the directories in an array. Make sure to properly quote directories
# with spaces in their paths.
directories=(
  "/Users/rahulmitra/Desktop/ski_coach/ski_coach/ski_coach"
  "/Users/rahulmitra/Desktop/ski_coach/ski_coach/watch_ski_coach Watch App"
)

for dir in "${directories[@]}"; do
  echo "========================"
  echo "Directory: $dir"
  echo "========================"

  # Find all .swift files in the current directory and iterate over them
  find "$dir" -type f -name "*.swift" | while read -r file; do
    # Print the filename
    echo "Filename: $(basename "$file")"
    
    # Print the file contents
    cat "$file"
    
    # Add a blank line for readability
    echo
  done
done
