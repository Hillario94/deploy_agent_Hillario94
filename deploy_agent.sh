#!/bin/bash
PN=""; cleanup(){ echo "[!] Interrupted"; if [ -n "$PN" ] && [ -d "attendance_tracker_$PN" ]; then zip -r "attendance_tracker_${PN}_archive.zip" "attendance_tracker_$PN" >/dev/null 2>&1; rm -rf "attendance_tracker_$PN"; fi; exit 1; }
deploy(){
command -v python3 >/dev/null || { echo "no python3"; exit 1; }
command -v zip >/dev/null || { echo "no zip"; exit 1; }
read -p "project name: " n; [ -z "$n" ] && return 1; PN=$n; D="attendance_tracker_$n"
trap cleanup SIGINT SIGTSTP
if [ -d "$D" ]; then read -p "overwrite/abort: " c; [[ $c == overwrite* ]] || { trap - SIGINT SIGTSTP; PN=""; return 1; }; rm -rf "$D"; fi
mkdir -p "$D/Helpers" "$D/reports"
cp templates/attendance_checker.py "$D"/; cp templates/config.json "$D"/; cp templates/config.json "$D/Helpers/"
read -p "Roster A/B: " r
if [[ $r == A* || $r == a* ]]; then read -p "N 1-10: " N; head -n $((N+1)) templates/assets.csv > "$D/Helpers/assets.csv"; cp "$D/Helpers/assets.csv" "$D/assets.csv"; sed -i 's/"total_sessions":.*/"total_sessions": 5/' "$D/config.json" "$D/Helpers/config.json"
else read -p "N 1-10: " N; echo "$(head -n1 templates/assets.csv)" > "$D/Helpers/assets.csv"; for ((i=0;i<N;i++)); do echo "test${i}@e.com,Student${i},0,0" >> "$D/Helpers/assets.csv"; done; cp "$D/Helpers/assets.csv" "$D/assets.csv"; sed -i 's/"total_sessions":.*/"total_sessions": 1/' "$D/config.json" "$D/Helpers/config.json"; fi
chmod +x "$D/attendance_checker.py"; chmod 600 "$D/config.json" "$D/Helpers/config.json"
read -p "update threshold y/n: " u; if [[ $u == y* ]]; then read -p "warning [75]: " w; read -p "failure [50]: " f; w=${w:-75}; f=${f:-50}; sed -i "s/\"warning\":.*/\"warning\": $w,/" "$D/config.json" "$D/Helpers/config.json"; sed -i "s/\"failure\":.*/\"failure\": $f/" "$D/config.json" "$D/Helpers/config.json"; fi
trap - SIGINT SIGTSTP; ls -R "$D"; PN="$n"; run_app "$n"; PN=""; }
run_app(){ p=$1; [ -z "$p" ] && read -p "project: " p; [ -d "attendance_tracker_$p" ] && (cd "attendance_tracker_$p" && python3 attendance_checker.py); }
archive_logs(){ read -p "project: " p; D="attendance_tracker_$p"; mkdir -p archives/attendance archives/absent; ts=$(date +%Y%m%d_%H%M%S); [ -f "$D/reports/attendance.log" ] && cp "$D/reports/attendance.log" "archives/attendance/attendance_${ts}.log"; [ -f "$D/reports/absent.log" ] && cp "$D/reports/absent.log" "archives/absent/absent_${ts}.log"; echo "archived $ts"; }
while true; do echo "1)Deploy 2)Run 3)Archive 4)Exit"; read -p "> " o; case $o in 1) deploy;; 2) run_app;; 3) archive_logs;; 4) exit 0;; esac; done
