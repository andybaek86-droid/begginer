# 작업 인수인계 (새 세션용)

이 파일을 새 Claude 세션에 읽히면 이어서 작업할 수 있다.

## 지금까지 한 것
- 로블록스 수익 구조(게임패스·개발자 상품·프리미엄 페이아웃·DevEx) 조사 및 99 Nights 수익 추정
- WoW 스타일 육성 RPG 기획서: `docs/roblox-wow-like-rpg-plan.md`
- Rojo 기반 Luau 프로토타입: `roblox-rpg/` (전사 스킬 3종, 몬스터 2종 AI, 레벨업, DataStore 저장, HUD)
- Studio 명령 모음용 원클릭 설치 코드: `roblox-rpg/install.lua`
  - 실행하면 `ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayerScripts/Main`을 생성(기존 동명 항목은 교체)

## 현재 상태
- 사용자는 회사 PC(Windows, 한국어 Roblox Studio 새 UI)에서 Baseplate 장소를 열어 둠
- `install.lua` 전체를 명령 모음에 붙여넣었으나, 실행 여부가 불확실. Play 화면에서 몬스터와 HUD가 보이지 않음
- 출력(Output) 창 위치를 아직 못 찾음 (새 UI에서는 "보기" 메뉴에 없음 → "창" 메뉴 또는 "스크립트" 탭 확인 필요)
- 코드는 Studio에서 한 번도 실행 검증되지 않음

## 다음 할 일
1. Play 중이면 중지(■)
2. 명령 모음의 `install.lua` 실행 → 출력 창에 `RPG 프로토타입 설치 완료!` 확인
3. Play(▶) → 하단 경험치 바/스킬 버튼, 슬라임(+X)·고블린(-X) 확인, 키 1로 공격
4. 오류가 나면 출력 창 메시지를 보고 `roblox-rpg/src/` 수정 → `install.lua` 재생성
   (install.lua는 src의 각 파일을 `[==[ ... ]==]` 문자열로 감싸 `add(...)`하는 구조)
5. 이후 후보: 인벤토리/장비, 퀘스트, 추가 직업, ProfileStore 세션 락

## 사용자 메모
- 초보자. Studio UI 위치를 구체적으로(가능하면 스크린샷 표시로) 안내해야 함
- 한국어로 소통
