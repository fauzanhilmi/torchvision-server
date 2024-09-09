#!/bin/bash

# # Read the JSON file
json=$(cat models_one_run.json)

# # Use jq to parse the JSON and create a dictionary in the shell script
# declare -A dictionary

# # Loop through each key-value pair in the JSON
# for key in $(echo $json | jq -r 'keys[]'); do
#     values=$(echo $json | jq -r --arg k "$key" '.[$k][]')
#     dictionary[$key]="$values"
# done

# # Print the dictionary to verify
# for key in "${!dictionary[@]}"; do
#     echo "$key: ${dictionary[$key]}"
# done

# Initialize an associative array
declare -A dict

# Loop over each key in the JSON object
for key in $(echo $json | jq -r 'keys[]'); do
    # Extract the values corresponding to the current key
    values=$(echo $json | jq -r --arg k "$key" '.[$k][]')
    # Convert the newline-separated values into a space-separated string
    values_array=()
    for value in $values; do
        values_array+=($value)
    done
    # Store the array as a string in the associative array
    dict[$key]="${values_array[@]}"
done

# Example of accessing and using the array stored in the associative array
for key in "${!dict[@]}"; do
    echo "Key: $key"
    # Convert the string back to an array
    values_array=(${dict[$key]})
    for value in "${values_array[@]}"; do
        echo "  Value: $value"
    done
done