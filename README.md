# Automated Project Bootstrapping - deploy_agent_Hillario94

## 1. How to Run
chmod +x deploy_agent.sh
./deploy_agent.sh
Menu:
1 Deploy -> ask name, A/B roster, count, thresholds y/n
2 Run -> ask name, runs python3 attendance_checker.py
3 Archive -> ask name, archives logs with timestamp
4 Exit

Example: ./deploy_agent.sh -> 1 -> demo1 -> A -> 2 -> no -> P P -> 3 -> demo1 -> 4

## 2. Threshold Update
During deploy asks y/n to update thresholds. If yes, reads warning and failure, checks numeric with regex, uses sed -i to edit "warning": <num> and "failure": <num> in Helpers/config.json. File stays same format. chmod 600 set.

## 3. Log Archiving
Checks reports/attendance.log and reports/absent.log exist. Copies to archives/attendance/attendance_YYYYMMDD_HHMMSS.log and archives/absent/absent_YYYYMMDD_HHMMSS.log. Prints paths. If missing, prints not found and continues.

## 4. Trap Ctrl+C / Ctrl+Z
Trap active during deploy only. On Ctrl+C or Ctrl+Z: prints interrupted message, zip -r project_archive.zip project/, rm -rf incomplete dir, exit clean. Test: run deploy and press Ctrl+C fast, then ls *.zip.

## 5. Tested Structure
ls -R shows attendance_checker.py (+x), assets.csv, Helpers/config.json (600) and Helpers/assets.csv, reports/ with logs, archives/ after archive. Pre-flight checks python3 and zip.

## 6. Video
Video Link: PASTE_YOUR_LINK_HERE
GitHub: https://github.com/Hillario94/deploy_agent_Hillario94/tree/dev
