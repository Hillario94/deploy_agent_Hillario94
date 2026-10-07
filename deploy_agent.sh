#!/bin/bash
PN=""
cleanup(){
  echo "[!] Interrupted"
  if [ -n "$PN" ] && [ -d "attendance_tracker_$PN" ]; then
    rm -rf "attendance_tracker_$PN"
  fi
  exit 1
}
deploy(){
  read -p "project name: " n
  [ -z "$n" ] && { echo "empty"; return 1; }
  PN=$n
  D="attendance_tracker_$n"
  trap cleanup SIGINT SIGTSTP
  if [ -d "$D" ]; then rm -rf "$D"; fi
  mkdir -p "$D/Helpers" "$D/reports"
  cp templates/attendance_checker.py "$D"/
  cp templates/config.json "$D"/
  cp templates/config.json "$D/Helpers/config.json"
  read -p "Roster A=existing B=fresh [A/B]: " r
  if [[ $r == A* || $r == a* ]]; then
    read -p "students 1-10: " N
    head -n $((N+1)) templates/assets.csv > "$D/Helpers/assets.csv"
    cp "$D/Helpers/assets.csv" "$D/assets.csv"
  else
    read -p "students 1-10: " N
    head -n1 templates/assets.csv > "$D/Helpers/assets.csv"
    for ((i=1;i<=N;i++)); do echo "s${i}@e.com,Student${i},0,0" >> "$D/Helpers/assets.csv"; done
    cp "$D/Helpers/assets.csv" "$D/assets.csv"
  fi
  chmod +x "$D/attendance_checker.py"
  chmod 600 "$D/config.json" "$D/Helpers/config.json"
  read -p "update threshold yes/no: " u
  if [[ $u == y* ]]; then
    read -p "warning [75]: " w; read -p "failure [50]: " f; w=${w:-75}; f=${f:-50}
    sed -i "s/\"warning\":.*/\"warning\": $w,/" "$D/config.json"
    sed -i "s/\"failure\":.*/\"failure\": $f/" "$D/config.json"
  fi
  trap - SIGINT SIGTSTP
  echo "deployed $D"
  PN="$n"
  run_app "$n"
  PN=""
}
run_app(){
  p=${1:-""}; [ -z "$p" ] && read -p "project to run: " p
  [ -d "attendance_tracker_$p" ] || { echo "not found"; return 1; }
  (cd "attendance_tracker_$p" && python3 attendance_checker.py)
}
archive_logs(){
  read -p "project to archive: " p
  D="attendance_tracker_$p"; [ -d "$D" ] || { echo "not found"; return 1; }
  mkdir -p archives/attendance archives/absent; ts=$(date +%Y%m%d_%H%M%S)
  if [ -f "$D/reports/attendance.log" ]; then cp "$D/reports/attendance.log" "archives/attendance/attendance_${ts}.log"; echo "archived"; else echo "no attendance.log"; fi
  if [ -f "$D/reports/absent.log" ]; then cp "$D/reports/absent.log" "archives/absent/absent_${ts}.log"; echo "archived"; else echo "no absent.log"; fi
}
while true; do echo ""; echo "1)Deploy 2)Run 3)Archive 4)Exit"; read -p "> " o; case $o in 1) deploy;; 2) run_app;; 3) archive_logs;; 4) exit 0;; *) echo invalid;; esac; done
