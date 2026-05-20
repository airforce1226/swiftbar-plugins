# SwiftBar Plugins — Crypto

[SwiftBar](https://swiftbar.app/) 메뉴바 플러그인 모음입니다. 비트코인 실시간 가격과
BTCZ ETF(T-Rex 2X Inverse Bitcoin Daily Target) 장중 추정가를 표시합니다.

## 플러그인

### `btc-price.5s.sh`
- Coinbase spot price 실시간 표시
- 24h 변동률 + 색상 (상승 초록 `#16c784` / 하락 빨강 `#ea3943`)
- 드롭다운에 24h Open / High / Low

예시:
```
₿ $76,859.49 ▼-1.54%
```

### `btcz-etf.5s.sh`
- BTCZ ETF의 **장중 추정가**(implied price) 계산 — 미국 장 마감 시간에도 실시간 BTC
  가격 변동을 -2x 레버리지로 반영해서 "지금 시장이 열려 있다면 얼마일지"를 보여줍니다.
- **일일 EMA 캘리브레이션**: 매일 ETF 실제 종가가 나오면 이론값과 실제값의 비율을 EMA로
  누적 학습 → 운용비용 + slippage가 자동 보정됩니다 (5일치 이상 쌓이면 `✓` 표시).
- (선택) 본인 포지션 변수를 설정하면 USD 손익 + USD/KRW 환차를 분리한 KRW 손익까지 함께 표시됩니다.

예시 (포지션 미설정):
```
BTCZ $4.097 ▲+6.41% ·
```

예시 (포지션 설정 시):
```
BTCZ $4.103 ▲+4.53% (+₩874,066) ·
```

#### 포지션 설정 (선택)
스크립트 상단 세 변수를 본인 값으로 수정하세요:
```python
AVG_COST = 3.9357   # USD, 본인 평균단가
SHARES   = 3285     # 보유 수량
BUY_FX   = 1491.88  # 매입 시점 USD/KRW 환율
```
세 값이 모두 0보다 크면 Position / KRW 환산 / 환차 손익 섹션이 활성화됩니다.

#### Broker anchor (선택)
ETF NAV / broker 데이터 source 와 우리 추정 사이에 systematic bias 가 있을 수 있습니다
(보통 0.5~1% 수준). broker 앱에서 본 정확한 가격을 알면 즉시 일치시킬 수 있습니다:
```python
BROKER_PRICE = 4.040   # broker 가 보여주는 BTCZ 가격
```
- 설정하면 그 시점의 `BROKER_PRICE / raw_implied` 가 calibration factor 로 계산되어
  state 에 **freeze** 됩니다. 이후 BTC 가 움직이면 implied 가 그에 따라 자연스럽게 변동
  (factor 는 frozen, BTC 변동만 새로 반영). 메뉴바에 `M` 표시.
- `BROKER_PRICE` 값을 다른 숫자로 바꾸면 anchor 가 그 시점에 다시 계산됩니다.
- `None` 으로 두면 EMA 자동 학습 모드 (며칠 누적되면 정확해짐, `✓` 표시).

## 요구사항

- macOS
- [SwiftBar](https://github.com/swiftbar/SwiftBar) (Homebrew: `brew install --cask swiftbar`)
- python3 (macOS 기본 탑재)

## 설치

```bash
git clone https://github.com/airforce1226/swiftbar-plugins.git
cd swiftbar-plugins
chmod +x *.sh
```

SwiftBar 환경설정에서 지정한 plugin 디렉토리(예: `~/Documents/SwiftBarPlugins`)에 복사
또는 심볼릭 링크하세요:
```bash
ln -s "$(pwd)/btc-price.5s.sh"  ~/Documents/SwiftBarPlugins/
ln -s "$(pwd)/btcz-etf.5s.sh"   ~/Documents/SwiftBarPlugins/
open "swiftbar://refreshallplugins"
```

## 데이터 소스

- BTC spot price: Coinbase Wallet API (`api.coinbase.com/v2/prices/BTC-USD/spot`)
- BTC historical (4PM ET reference): Coinbase Exchange candles (`api.exchange.coinbase.com/products/BTC-USD/candles`) — Yahoo Finance fallback
- BTCZ ETF: Yahoo Finance chart API
- USD/KRW: Yahoo Finance chart API

## 동작 원리 — BTCZ 추정가

```
implied_price = ETF_last_close × (1 − 2 × BTC_change) × factor
BTC_change    = (BTC_now − BTC_at_4PM_ET) / BTC_at_4PM_ET
```

- **BTC reference 시점**: ETF 의 NAV 계산 기준인 4PM ET 의 BTC 가격을 사용합니다
  (regularMarketTime 이 아닌 정확한 4PM 로 강제 변환 → broker NAV 와 시점 정합성 확보).
- **factor** 결정:
  - `BROKER_PRICE` 설정 시: `BROKER_PRICE / raw_implied` (강제 anchor)
  - 그 외: 매일 1회 EMA 학습으로 누적
    ```
    theoretical_today = ETF_close_yesterday × (1 − 2 × BTC_change_during_session)
    ratio             = ETF_close_today / theoretical_today
    factor            = (1 − α) × factor + α × ratio          # α = 0.25
    ```

## Disclaimer

본 플러그인은 정보 제공 목적입니다. 표시되는 가격/손익은 추정값이며 실제 매매 결과와
다를 수 있습니다. 투자 결정에 대한 책임은 사용자 본인에게 있습니다.

## 라이선스

MIT — [LICENSE](LICENSE) 참고
