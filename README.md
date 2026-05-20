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
- BTC 24h stats: Coinbase Exchange API (`api.exchange.coinbase.com/products/BTC-USD/stats`)
- BTC historical: Yahoo Finance chart API
- BTCZ ETF: Yahoo Finance chart API
- USD/KRW: Yahoo Finance chart API

## 동작 원리 — BTCZ 추정가

```
implied_price = ETF_last_close × (1 − 2 × BTC_change) × calibration_factor
BTC_change    = (BTC_now − BTC_at_ETF_close) / BTC_at_ETF_close
```

캘리브레이션 (매일 1회 갱신):
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
