#!/bin/bash

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
    command -v python3 >/dev/null || { echo "python3 not found!"; return; }
    command -v zip >/dev/null || { echo "zip not found!"; return; }
    echo "python3 and zip OK"

    read -p "Enter project name: " pname
    PROJECT_NAME="attendance_tracker_${pname}"
    PROJECT_DIR="$PROJECT_NAME"
    
    if [ -d "$PROJECT_DIR" ]; then
        read -p "Directory exists. Overwrite? (y/n): " ans
        if [[ "$ans" != "y" ]]; then
            echo "Aborted."
            return
        fi
        rm -rf "$PROJECT_DIR"
    fi

    mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" "$PROJECT_DIR/archives/attendance" "$PROJECT_DIR/archives/absent"

    cp templates/attendance_checker.py "$PROJECT_DIR/"
    cp templates/config.json "$PROJECT_DIR/Helpers/"
    
    read -p "Choose roster: A=copy from template, B=generate fresh (A/B): " choice
    read -p "How many students? " count

    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "Count must be numeric!"
        return
    fi

    if [[ "$choice" == "A" || "$choice" == "a" ]]; then
        head -n 1 templates/assets.csv > "$PROJECT_DIR/Helpers/assets.csv"
        head -n $((count+1)) templates/assets.csv | tail -n $count >> "$PROJECT_DIR/Helpers/assets.csv"
        cp "$PROJECT_DIR/Helpers/assets.csv" "$PROJECT_DIR/assets.csv"
    else
        echo "Email,Names,Attendance Count,Absence Count" > "$PROJECT_DIR/Helpers/assets.csv"
        names=("Alice Johnson" "Bob Smith" "Charlie Brown" "David Lee" "Emma Wilson")
        emails=("alice@example.com" "bob@example.com" "charlie@example.com" "david@example.com" "emma@example.com")
        for ((i=0;i<count;i++)); do
            idx=$((i % 5))
            echo "${emails[$idx]},${names[$idx]},0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
        done
        cp "$PROJECT_DIR/Helpers/assets.csv" "$PROJECT_DIR/assets.csv"
        sed -i 's/"total_sessions": 5/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json"
    fi

    chmod +x "$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$PROJECT_DIR/Helpers/config.json"
    echo "Permissions set: +x for .py, 600 for config.json"

    read -p "Update thresholds? (y/n): " up
    if [[ "$up" == "y" ]]; then
        read -p "Enter new warning threshold (default 75): " warn
        read -p "Enter new failure threshold (default 50): " fail
        if ! [[ "$warn" =~ ^[0-9]+$ ]] || ! [[ "$fail" =~ ^[0-9]+$ ]]; then
            echo "Error: thresholds must be numeric!"
            return
        fi
        sed -i "s/\"warning\": [0-9]*/\"warning\": $warn/" "$PROJECT_DIR/Helpers/config.json"
        sed -i "s/\"failure\": [0-9]*/\"failure\": $fail/" "$PROJECT_DIR/Helpers/config.json"
        echo "Thresholds updated."
    fi

    trap - SIGINT SIGTSTP
    echo "Deploy done. Verifying..."
    cd "$PROJECT_DIR" && python3 attendance_checker.py
    cd ..
}

run_app() {
    read -p "Enter project name: " pname
    PROJECT_DIR="attendance_tracker_${pname}"
    if [ ! -d "$PROJECT_DIR" ]; then echo "Not found!"; return; fi
    cd "$PROJECT_DIR" && python3 attendance_checker.py
    cd ..
}

archive_logs() {
    read -p "Enter project name: " pname
    PROJECT_DIR="attendance_tracker_${pname}"
    if [ ! -d "$PROJECT_DIR" ]; then echo "Not found!"; return; fi
    TS=$(date +%Y%m%d_%H%M%S)
    if [ -f "$PROJECT_DIR/reports/attendance.log" ]; then
        cp "$PROJECT_DIR/reports/attendance.log" "$PROJECT_DIR/archives/attendance/attendance_${TS}.log"
        echo "Archived: archives/attendance/attendance_${TS}.log"
    else
        echo "attendance.log not found"
    fi
    if [ -f "$PROJECT_DIR/reports/absent.log" ]; then
        cp "$PROJECT_DIR/reports/absent.log" "$PROJECT_DIR/archives/absent/absent_${TS}.log"
        echo "Archived: archives/absent/absent_${TS}.log"
    else
        echo "absent.log not found"
    fi
}

while true; do
    echo ""
    echo "1) Deploy 2) Run 3) Archive 4) Exit"
    read -p "Choose: " opt
    case $opt in
        1) deploy ;;
        2) run_app ;;
        3) archive_logs ;;
        4) exit 0 ;;
        *) echo "Invalid" ;;
    esac
done
