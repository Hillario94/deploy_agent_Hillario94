#!/usr/bin/env bash

PROJECT_DIR=""
PROJECT_NAME=""

cleanup() {
    echo ""
    echo "[!] Deployment interrupted by user!"
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        echo "[*] Archiving incomplete project..."
        zip -r "${PROJECT_NAME}_archive.zip" "$PROJECT_DIR" > /dev/null 2>&1
        echo "[*] Archived to ${PROJECT_NAME}_archive.zip"
        rm -rf "$PROJECT_DIR"
        echo "[*] Incomplete directory deleted."
    fi
    echo "[*] Exiting cleanly."
    exit 1
}

deploy() {
    trap cleanup SIGINT SIGTSTP

    echo "=== Pre-flight Checks ==="
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is not installed!"
        return 1
    fi
    if ! command -v zip >/dev/null 2>&1; then
        echo "Error: zip is not installed!"
        return 1
    fi
    echo "Pre-flight checks passed: python3 and zip are available."

    read -r -p "Enter project directory suffix: " pname
    if [ -z "$pname" ]; then
        echo "Error: Project name cannot be empty!"
        return 1
    fi

    PROJECT_NAME="attendance_tracker_${pname}"
    PROJECT_DIR="$PROJECT_NAME"

    if [ -d "$PROJECT_DIR" ]; then
        read -r -p "Directory '${PROJECT_DIR}' already exists. Overwrite? (y/n): " ans
        if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
            echo "Deployment aborted."
            return 1
        fi
        rm -rf "$PROJECT_DIR"
    fi

    mkdir -p "$PROJECT_DIR/Helpers" \
             "$PROJECT_DIR/reports" \
             "$PROJECT_DIR/archives/attendance" \
             "$PROJECT_DIR/archives/absent"

    cp templates/attendance_checker.py "$PROJECT_DIR/"
    cp templates/config.json "$PROJECT_DIR/Helpers/"

    read -r -p "Choose roster option (A: copy from template, B: generate fresh): " choice
    read -r -p "How many students? " count

    if ! [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: Student count must be a positive integer!"
        return 1
    fi

    if [[ "$choice" == "A" || "$choice" == "a" ]]; then
        head -n "$((count + 1))" templates/assets.csv > "$PROJECT_DIR/Helpers/assets.csv"
    elif [[ "$choice" == "B" || "$choice" == "b" ]]; then
        echo "Email,Names,Attendance Count,Absence Count" > "$PROJECT_DIR/Helpers/assets.csv"
        names=("Alice Johnson" "Bob Smith" "Charlie Brown" "David Lee" "Emma Wilson")
        emails=("alice@example.com" "bob@example.com" "charlie@example.com" "david@example.com" "emma@example.com")
        
        for ((i=0; i<count; i++)); do
            idx=$((i % 5))
            echo "${emails[$idx]},${names[$idx]},0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
        done

        sed -i 's/"total_sessions": *[0-9]*/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json"
    else
        echo "Error: Invalid roster option selected!"
        return 1
    fi

    chmod +x "$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$PROJECT_DIR/Helpers/config.json"
    echo "Permissions set: executable (+x) on attendance_checker.py, read/write (600) on config.json."

    read -r -p "Update attendance alert thresholds? (y/n): " up
    if [[ "$up" == "y" || "$up" == "Y" ]]; then
        read -r -p "Enter new warning threshold (default 75): " warn
        read -r -p "Enter new failure threshold (default 50): " fail

        if ! [[ "$warn" =~ ^[0-9]+$ ]] || ! [[ "$fail" =~ ^[0-9]+$ ]]; then
            echo "Error: Threshold values must be numeric!"
            return 1
        fi

        sed -i "s/\"warning\": *[0-9]*/\"warning\": $warn/" "$PROJECT_DIR/Helpers/config.json"
        sed -i "s/\"failure\": *[0-9]*/\"failure\": $fail/" "$PROJECT_DIR/Helpers/config.json"
        echo "Thresholds updated successfully."
    fi

    trap - SIGINT SIGTSTP
    echo "Deployment complete. Running verification test..."

    (cd "$PROJECT_DIR" && python3 attendance_checker.py)
}

run_app() {
    read -r -p "Enter project directory suffix: " pname
    local target="attendance_tracker_${pname}"

    if [ ! -d "$target" ]; then
        echo "Error: Directory '$target' not found!"
        return 1
    fi

    (cd "$target" && python3 attendance_checker.py)
}

archive_logs() {
    read -r -p "Enter project directory suffix: " pname
    local target="attendance_tracker_${pname}"

    if [ ! -d "$target" ]; then
        echo "Error: Directory '$target' not found!"
        return 1
    fi

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")

    mkdir -p "$target/archives/attendance" "$target/archives/absent"

    if [ -f "$target/reports/attendance.log" ]; then
        cp "$target/reports/attendance.log" "$target/archives/attendance/attendance_${ts}.log"
        echo "Archived: $target/archives/attendance/attendance_${ts}.log"
    else
        echo "Notice: reports/attendance.log not found, skipping."
    fi

    if [ -f "$target/reports/absent.log" ]; then
        cp "$target/reports/absent.log" "$target/archives/absent/absent_${ts}.log"
        echo "Archived: $target/archives/absent/absent_${ts}.log"
    else
        echo "Notice: reports/absent.log not found, skipping."
    fi
}

while true; do
    echo ""
    echo "======================================"
    echo " Attendance Tracker Deployment Agent  "
    echo "======================================"
    echo "1) Deploy Application"
    echo "2) Run Application"
    echo "3) Archive Logs"
    echo "4) Exit"
    read -r -p "Select an option [1-4]: " opt

    case "$opt" in
        1) deploy ;;
        2) run_app ;;
        3) archive_logs ;;
        4) echo "Exiting."; exit 0 ;;
        *) echo "Invalid option. Please enter 1, 2, 3, or 4." ;;
    esac
done
