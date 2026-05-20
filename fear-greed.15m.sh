#!/bin/bash
# <swiftbar.title>Fear & Greed Index</swiftbar.title>
# <swiftbar.version>v1.0</swiftbar.version>
# <swiftbar.author>airforce1226</swiftbar.author>
# <swiftbar.desc>Crypto Fear & Greed Index (alternative.me)</swiftbar.desc>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

/usr/bin/python3 <<'PYEOF'
import json
import urllib.request
import datetime


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.load(r)


try:
    d = fetch("https://api.alternative.me/fng/?limit=14")
    rows = d["data"]
    cur = rows[0]
    val = int(cur["value"])
    cls = cur["value_classification"]
except Exception as e:
    print("F&G ⚠️")
    print("---")
    print(f"Fetch failed: {e}")
    print("Refresh | refresh=true")
    raise SystemExit(0)

if val < 25:
    color = "#16c784"
    arrow = "↑↑"
elif val < 50:
    color = "#7ec784"
    arrow = "↑"
elif val < 55:
    color = "#888888"
    arrow = "·"
elif val < 75:
    color = "#f5a623"
    arrow = "↓"
else:
    color = "#ea3943"
    arrow = "↓↓"

print(f"F&G {val} {cls} {arrow} | color={color}")
print("---")
print(f"Today: {val}  {cls}")
print("---")
print("Last 14 days")
print("(bar = value / 5)")
for row in rows:
    ts = datetime.datetime.fromtimestamp(int(row["timestamp"]), tz=datetime.timezone.utc).strftime("%m-%d")
    v = int(row["value"])
    c = row["value_classification"]
    bar = "█" * max(v // 5, 1)
    print(f"{ts}  {v:>3}  {bar} {c}")
print("---")
print("Scale")
print("0-24   Extreme Fear   (contrarian buy)")
print("25-49  Fear")
print("50-54  Neutral")
print("55-74  Greed")
print("75-100 Extreme Greed  (contrarian sell)")
print("---")
ts = datetime.datetime.fromtimestamp(int(cur["timestamp"]), tz=datetime.timezone.utc)
print(f"Updated:     {ts.strftime('%Y-%m-%d %H:%M UTC')}")
secs = int(cur.get("time_until_update", 0) or 0)
if secs:
    hrs = secs // 3600
    mins = (secs % 3600) // 60
    print(f"Next update: in {hrs}h {mins}m")
print("---")
print("Open alternative.me | href=https://alternative.me/crypto/fear-and-greed-index/")
print("Refresh | refresh=true")
PYEOF
