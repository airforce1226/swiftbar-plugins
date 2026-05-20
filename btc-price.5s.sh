#!/bin/bash
# <swiftbar.title>BTC Price</swiftbar.title>
# <swiftbar.version>v1.2</swiftbar.version>
# <swiftbar.author>airforce1226</swiftbar.author>
# <swiftbar.desc>Coinbase BTC spot price with 24h change (locale-safe formatting)</swiftbar.desc>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

/usr/bin/python3 <<'PYEOF'
import json
import urllib.request

UA = {"User-Agent": "Mozilla/5.0"}


def fetch(url, timeout=4):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


try:
    spot = fetch("https://api.coinbase.com/v2/prices/BTC-USD/spot")
    amount = float(spot["data"]["amount"])
except Exception as e:
    print("₿ ⚠️")
    print("---")
    print(f"Spot fetch failed: {e}")
    print("Refresh | refresh=true")
    raise SystemExit(0)

open_ = high = low = None
try:
    stats = fetch("https://api.exchange.coinbase.com/products/BTC-USD/stats")
    open_ = float(stats["open"])
    high = float(stats["high"])
    low = float(stats["low"])
except Exception:
    pass

if open_:
    change_pct = (amount - open_) / open_ * 100.0
    is_up = change_pct >= 0
    arrow = "▲" if is_up else "▼"
    sign = "+" if is_up else ""
    color = "#16c784" if is_up else "#ea3943"
    print(f"₿ ${amount:,.2f} {arrow}{sign}{change_pct:.2f}% | color={color}")
else:
    print(f"₿ ${amount:,.2f}")

print("---")
print(f"Spot: ${amount:,.2f} USD")
if open_:
    print(f"24h Open: ${open_:,.2f}")
    print(f"24h High: ${high:,.2f}")
    print(f"24h Low:  ${low:,.2f}")
print("---")
print("Open Coinbase | href=https://www.coinbase.com/price/bitcoin")
print("Refresh | refresh=true")
PYEOF
