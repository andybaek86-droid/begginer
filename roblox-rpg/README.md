# Roblox RPG 프로토타입 (Rojo)

기획서: [`../docs/roblox-wow-like-rpg-plan.md`](../docs/roblox-wow-like-rpg-plan.md)

## 포함된 기능
- 전사 스킬 3종 (Slash / Whirlwind / Heavy Strike), 쿨다운·레벨 해금·치명타
- 몬스터 2종(Slime, Goblin): 어그로 추적, 공격, 리쉬, 리스폰
- 경험치/레벨업/스탯 성장, 골드 드랍
- DataStore 저장 (재시도, 로드 실패 시 덮어쓰기 방지, 자동 저장)
- HUD(경험치 바, 스킬 버튼), 데미지 숫자

## 실행 방법
1. [Rojo](https://rojo.space) 설치 (Studio 플러그인 + CLI)
2. 이 폴더에서 `rojo serve` 실행
3. Roblox Studio에서 새 Baseplate를 열고 Rojo 플러그인으로 Connect
4. Play. 스킬은 키 `1` `2` `3` 또는 화면 버튼. 몬스터 근처(스킬 사거리)에서 사용하면 가장 가까운 대상을 자동 타겟팅합니다.

저장 테스트는 Studio의 *Game Settings → Security → Enable Studio Access to API Services*를 켜야 합니다.

## 구조
| 파일 | 역할 |
|---|---|
| `src/shared/Config.luau` | 스탯/스킬/몬스터/스폰 수치 |
| `src/shared/Remotes.luau` | RemoteEvent 생성·접근 |
| `src/server/PlayerData.luau` | DataStore |
| `src/server/Leveling.luau` | XP, 레벨, 스탯 |
| `src/server/MobService.luau` | 몬스터 AI/스폰 |
| `src/server/Combat.luau` | 스킬 검증·데미지 |
| `src/client/Main.client.luau` | HUD·입력·데미지 숫자 |

## 알려진 한계 (다음 작업 후보)
- 코드는 Studio에서 실행 테스트하지 못한 상태입니다. 첫 실행 시 수정이 필요할 수 있습니다.
- 클라이언트 쿨다운 표시는 대상이 없어도 시작되고, 서버는 대상이 있을 때만 쿨다운을 소모합니다.
- 세션 락 없음 (다중 서버 동시 접속 시 데이터 충돌 가능). 출시 전 ProfileStore 등 도입 권장.
- 직업은 전사 1종, 아이템/인벤토리/퀘스트/던전/파티는 미구현.
- 몬스터는 단색 블록 모델 (아트 교체 필요).
