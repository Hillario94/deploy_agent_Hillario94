import csv,os
os.makedirs("reports",exist_ok=True)
with open("assets.csv") as f:
    rows=list(csv.DictReader(f))
for r in rows:
    s=input(f"Mark {r['name']} P/A: ").strip().upper()
    print(f" -> {s}")
open("reports/attendance.log","w").write("attendance log\n")
open("reports/absent.log","w").write("absent log\n")
print("checker done")
