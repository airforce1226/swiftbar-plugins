#!/bin/bash
# <swiftbar.title>BTCZ ETF (implied)</swiftbar.title>
# <swiftbar.version>v1.1</swiftbar.version>
# <swiftbar.author>airforce1226</swiftbar.author>
# <swiftbar.desc>BTCZ implied price (Coinbase BTC @ 4PM ET, -2x) with EMA calibration, optional broker anchor + KRW P/L</swiftbar.desc>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

# === 본인 포지션 (선택) =====================================
#   AVG_COST / SHARES / BUY_FX 세 값을 모두 0보다 크게 설정하면
#   Position / KRW 환산 / 환차 손익 섹션이 활성화됩니다.
# ============================================================
# === BROKER_PRICE (선택) ====================================
#   broker 앱에서 본 정확한 BTCZ 가격을 입력하면, 그 가격에
#   anchor 되도록 calibration factor 가 자동 계산됩니다 (M 표시).
#   None 이면 EMA 학습 factor 사용 (시간 지나면 자동 보정).
# ============================================================

/usr/bin/python3 <<'PYEOF'
import json
import os
import subprocess
import urllib.request
from datetime import datetime, timedelta, timezone

UA = {"User-Agent": "Mozilla/5.0"}
LEVERAGE = -2.0
EMA_ALPHA = 0.25
MAX_HISTORY = 60

AVG_COST = 0.0     # USD, 본인 평균단가 (예: 3.9357)
SHARES = 0         # 보유 수량 (예: 3285)
BUY_FX = 0.0       # 매입 시점 USD/KRW (예: 1491.88)
BROKER_PRICE = None  # broker 가격 (예: 4.040). None 이면 EMA 학습 사용.

START_DATE = None     # "YYYY-MM-DD" 매수일. None 이면 첫 실행일 자동 기록.
STOP_DAYS = 30        # 손절 알림 임계 (일수)
PROFIT_DAYS = 60      # 익절 알림 임계 (일수)

HAS_POSITION = AVG_COST > 0 and SHARES > 0 and BUY_FX > 0
COST_USD = AVG_COST * SHARES if HAS_POSITION else 0.0
COST_KRW_ACTUAL = COST_USD * BUY_FX if HAS_POSITION else 0.0

_plugin = os.environ.get("SWIFTBAR_PLUGIN_PATH")
if _plugin and os.path.isdir(os.path.dirname(_plugin)):
    STATE_PATH = os.path.join(os.path.dirname(_plugin), ".btcz-state.json")
else:
    STATE_PATH = os.path.expanduser("~/.btcz-swiftbar-state.json")


def fetch(url, timeout=5):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def load_state():
    try:
        with open(STATE_PATH) as f:
            s = json.load(f)
            s.setdefault("daily", [])
            s.setdefault("factor", 1.0)
            s.setdefault("samples", 0)
            return s
    except Exception:
        return {"daily": [], "factor": 1.0, "samples": 0}


def save_state(state):
    try:
        with open(STATE_PATH, "w") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass


def fail(msg):
    print("BTCZ ⚠️")
    print("---")
    print(msg)
    print("---")
    print("Open Yahoo Finance | href=https://finance.yahoo.com/quote/BTCZ")
    print("Refresh | refresh=true")
    raise SystemExit(0)


def btc_at(ts):
    try:
        candles = fetch(
            f"https://api.exchange.coinbase.com/products/BTC-USD/candles?start={ts-600}&end={ts+600}&granularity=60"
        )
        if candles:
            candles.sort(key=lambda x: abs(x[0] - ts))
            return float(candles[0][4])
    except Exception:
        pass
    try:
        hist = fetch(
            f"https://query1.finance.yahoo.com/v8/finance/chart/BTC-USD?period1={ts-300}&period2={ts+300}&interval=1m"
        )
        closes = hist["chart"]["result"][0]["indicators"]["quote"][0]["close"]
        return next((c for c in reversed(closes) if c is not None), None)
    except Exception:
        return None


def etf_close_ts(market_time, gmt_offset_sec):
    dt_utc = datetime.fromtimestamp(market_time, tz=timezone.utc)
    tz = timezone(timedelta(seconds=gmt_offset_sec))
    dt_local = dt_utc.astimezone(tz)
    dt_close_local = dt_local.replace(hour=16, minute=0, second=0, microsecond=0)
    return int(dt_close_local.astimezone(timezone.utc).timestamp())


def fmt_krw(v):
    if v is None:
        return "n/a"
    sign = "+" if v >= 0 else "-"
    return f"{sign}₩{abs(v):,.0f}"


def notify(title, msg, sound="Sosumi"):
    safe = msg.replace('"', '\\"')
    safe_title = title.replace('"', '\\"')
    script = f'display notification "{safe}" with title "{safe_title}" sound name "{sound}"'
    subprocess.run(["osascript", "-e", script], check=False)


try:
    btcz = fetch("https://query1.finance.yahoo.com/v8/finance/chart/BTCZ?interval=1d&range=2d")
    meta = btcz["chart"]["result"][0]["meta"]
    last_price = float(meta["regularMarketPrice"])
    prev_close = float(meta["chartPreviousClose"])
    last_time = int(meta["regularMarketTime"])
    gmt_offset = int(meta.get("gmtoffset", -14400))
    name = meta.get("longName", "BTCZ")
    day_high = meta.get("regularMarketDayHigh")
    day_low = meta.get("regularMarketDayLow")
    day_vol = meta.get("regularMarketVolume")
except Exception as e:
    fail(f"BTCZ fetch failed: {e}")

try:
    spot = fetch("https://api.coinbase.com/v2/prices/BTC-USD/spot")
    btc_now = float(spot["data"]["amount"])
except Exception as e:
    fail(f"BTC spot failed: {e}")

close_ts = etf_close_ts(last_time, gmt_offset)
btc_at_close = btc_at(close_ts)
ref_label = "BTC @ 4PM ET (Coinbase)"
if btc_at_close is None:
    try:
        stats = fetch("https://api.exchange.coinbase.com/products/BTC-USD/stats")
        btc_at_close = float(stats["open"])
        ref_label = "24h open (fallback)"
    except Exception as e:
        fail(f"BTC reference price failed: {e}")

fx = None
if HAS_POSITION:
    try:
        d = fetch("https://query1.finance.yahoo.com/v8/finance/chart/KRW=X?interval=1d&range=1d")
        fx = float(d["chart"]["result"][0]["meta"]["regularMarketPrice"])
    except Exception:
        fx = None

state = load_state()
today_iso = datetime.fromtimestamp(last_time, tz=timezone.utc).strftime("%Y-%m-%d")
existing_dates = {d["date"] for d in state["daily"]}

if today_iso not in existing_dates:
    state["daily"].append({
        "date": today_iso,
        "time": last_time,
        "btcz_close": last_price,
        "btc_at_close": btc_at_close,
    })
    state["daily"] = state["daily"][-MAX_HISTORY:]

    if len(state["daily"]) >= 2:
        prev = state["daily"][-2]
        curr = state["daily"][-1]
        if prev.get("btc_at_close") and curr.get("btc_at_close"):
            btc_chg = (curr["btc_at_close"] - prev["btc_at_close"]) / prev["btc_at_close"]
            theoretical = prev["btcz_close"] * (1.0 + LEVERAGE * btc_chg)
            if theoretical > 0:
                ratio = curr["btcz_close"] / theoretical
                if 0.5 < ratio < 1.5:
                    state["factor"] = (1.0 - EMA_ALPHA) * state["factor"] + EMA_ALPHA * ratio
                    state["samples"] += 1

    save_state(state)

today_local = datetime.now().date()
if START_DATE:
    try:
        start_date = datetime.strptime(START_DATE, "%Y-%m-%d").date()
    except Exception:
        start_date = None
else:
    saved = state.get("start_date")
    if saved:
        try:
            start_date = datetime.strptime(saved, "%Y-%m-%d").date()
        except Exception:
            start_date = today_local
            state["start_date"] = start_date.isoformat()
            save_state(state)
    else:
        start_date = today_local
        state["start_date"] = start_date.isoformat()
        save_state(state)

if start_date and HAS_POSITION:
    days_held = (today_local - start_date).days
    stop_remaining = STOP_DAYS - days_held
    profit_remaining = PROFIT_DAYS - days_held

    if days_held >= STOP_DAYS and not state.get("stop_alert_fired"):
        notify(
            "BTCZ 손절선 도달",
            f"매수 후 {days_held}일 경과 (≥ {STOP_DAYS}일). 청산 검토 권장.",
            "Submarine",
        )
        state["stop_alert_fired"] = True
        save_state(state)

    if days_held >= PROFIT_DAYS and not state.get("profit_alert_fired"):
        notify(
            "BTCZ 익절선 도달",
            f"매수 후 {days_held}일 경과 (≥ {PROFIT_DAYS}일). 청산 권장.",
            "Hero",
        )
        state["profit_alert_fired"] = True
        save_state(state)
else:
    days_held = None
    stop_remaining = None
    profit_remaining = None

btc_change = (btc_now - btc_at_close) / btc_at_close
raw_implied = last_price * (1.0 + LEVERAGE * btc_change)

if BROKER_PRICE and BROKER_PRICE > 0 and raw_implied > 0:
    if state.get("anchor_price") != BROKER_PRICE or state.get("anchor_factor") is None:
        factor = float(BROKER_PRICE) / raw_implied
        state["anchor_price"] = BROKER_PRICE
        state["anchor_factor"] = factor
        save_state(state)
    else:
        factor = state["anchor_factor"]
    samples = -1
    factor_source = f"anchor → ${BROKER_PRICE:,.4f} (frozen factor, BTC tracked)"
else:
    factor = state.get("factor", 1.0)
    samples = state.get("samples", 0)
    factor_source = "EMA learned"

implied = raw_implied * factor
implied_pct_vs_prev = (implied - prev_close) / prev_close * 100.0
btc_change_pct = btc_change * 100.0

cal_mark = "M" if samples < 0 else ("✓" if samples >= 5 else "·")

if HAS_POSITION:
    value_usd = implied * SHARES
    pl_usd = value_usd - COST_USD
    pl_pct_usd = (implied / AVG_COST - 1.0) * 100.0
    if fx:
        value_krw = value_usd * fx
        pl_krw_total = value_krw - COST_KRW_ACTUAL
        pl_krw_price = pl_usd * fx
        pl_krw_fx = COST_USD * (fx - BUY_FX)
        pl_pct_krw = (value_krw / COST_KRW_ACTUAL - 1.0) * 100.0
        head_up = pl_krw_total >= 0
        head_pct = pl_pct_krw
        head_extra = f"({fmt_krw(pl_krw_total)}) "
    else:
        head_up = pl_pct_usd >= 0
        head_pct = pl_pct_usd
        head_extra = ""
    arrow = "▲" if head_up else "▼"
    sign = "+" if head_up else ""
    color = "#16c784" if head_up else "#ea3943"
    print(f"BTCZ ${implied:,.3f} {arrow}{sign}{head_pct:.2f}% {head_extra}{cal_mark} | color={color}")
else:
    is_up = implied_pct_vs_prev >= 0
    arrow = "▲" if is_up else "▼"
    sign = "+" if is_up else ""
    color = "#16c784" if is_up else "#ea3943"
    print(f"BTCZ ${implied:,.3f} {arrow}{sign}{implied_pct_vs_prev:.2f}% {cal_mark} | color={color}")

print("---")
print(name)
print("---")
if HAS_POSITION:
    print("Position")
    print(f"Holdings: {SHARES:,} sh @ ${AVG_COST:,.4f}")
    print(f"Cost (USD):  ${COST_USD:,.2f}")
    print(f"Value (USD): ${value_usd:,.2f}")
    sign_usd = "+" if pl_usd >= 0 else ""
    print(f"P/L (USD):   {sign_usd}${pl_usd:,.2f}  ({sign_usd}{pl_pct_usd:.2f}%)")
    print("---")
    if start_date:
        print("Timeline")
        print(f"매수일:    {start_date.isoformat()}")
        print(f"경과:      D+{days_held}")
        if stop_remaining > 0:
            print(f"손절선:    D+{STOP_DAYS} ({stop_remaining}일 남음)")
        elif stop_remaining == 0:
            print(f"손절선:    ⚠️ 오늘 도달")
        else:
            print(f"손절선:    ⚠️ {-stop_remaining}일 초과 — 청산 검토")
        if profit_remaining > 0:
            print(f"익절선:    D+{PROFIT_DAYS} ({profit_remaining}일 남음)")
        elif profit_remaining == 0:
            print(f"익절선:    🟡 오늘 도달")
        else:
            print(f"익절선:    🟡 {-profit_remaining}일 초과 — 청산 권장")
        print("---")
    if fx:
        print(f"USD/KRW now:  ₩{fx:,.2f}")
        print(f"USD/KRW buy:  ₩{BUY_FX:,.2f}")
        print(f"Cost (KRW, 실매입):  ₩{COST_KRW_ACTUAL:,.0f}")
        print(f"Value (KRW, 현재):   ₩{value_krw:,.0f}")
        print(f"P/L price (KRW):     {fmt_krw(pl_krw_price)}   (USD 손익 × 현재환율)")
        print(f"P/L FX    (KRW):     {fmt_krw(pl_krw_fx)}   (매입원금 × 환율차)")
        print(f"P/L TOTAL (KRW):     {fmt_krw(pl_krw_total)}   ({'+' if pl_pct_krw >= 0 else ''}{pl_pct_krw:.2f}%)")
    else:
        print("USD/KRW: fetch failed (KRW values unavailable)")
else:
    print("Position not configured")
    print("Edit AVG_COST / SHARES / BUY_FX at top of this script to enable P/L.")
print("---")
print(f"Implied (calibrated): ~${implied:,.3f}")
print(f"Implied (raw):        ~${raw_implied:,.3f}")
if samples < 0:
    print(f"Calibration factor:   {factor:.5f}  ({factor_source})")
else:
    print(f"Calibration factor:   {factor:.5f}  ({factor_source}, samples: {samples})")
print("---")
print(f"Last Close: ${last_price:,.3f}  ({today_iso})")
print(f"Prev Close: ${prev_close:,.3f}")
sign_d = "+" if implied_pct_vs_prev >= 0 else ""
print(f"Implied vs Prev Close: {sign_d}{implied_pct_vs_prev:.2f}%")
if day_high is not None:
    print(f"Day High:   ${float(day_high):,.3f}")
if day_low is not None:
    print(f"Day Low:    ${float(day_low):,.3f}")
if day_vol is not None:
    print(f"Volume:     {int(day_vol):,}")
print("---")
print(f"BTC now:    ${btc_now:,.2f}")
print(f"BTC ref:    ${btc_at_close:,.2f}  ({ref_label})")
sign_b = "+" if btc_change_pct >= 0 else ""
print(f"BTC change: {sign_b}{btc_change_pct:.2f}%")
print(f"Leverage:   {LEVERAGE:+.1f}x")
print("---")
print(f"History: {len(state['daily'])} day(s)")
print(f"State file: {STATE_PATH}")
print("---")
print("Open Yahoo Finance | href=https://finance.yahoo.com/quote/BTCZ")
print("Refresh | refresh=true")
PYEOF
