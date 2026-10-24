# 스케줄러 비서

한국어로 일정을 등록하고 조회·알림받는 간단한 명령줄 도구입니다. (Python 3, 추가 설치 없음)

```bash
python scheduler.py add "팀 회의" 내일 오후 3시          # 일정 추가 (기본 60분)
python scheduler.py add "치과" 금 14:30 -m 30 -n "검진"   # 30분, 메모
python scheduler.py add "운동" 다음주 월요일 오전 7시 반
python scheduler.py today        # 오늘 일정
python scheduler.py week         # 앞으로 7일
python scheduler.py list [--all] # 다가오는 일정 (--all: 지난/완료 포함)
python scheduler.py done 1       # 완료 처리
python scheduler.py rm 1         # 삭제
python scheduler.py remind --within 30   # 30분 안에 시작하는 일정
```

- 날짜: `오늘 내일 모레`, `월~일 / 다음주 화요일`, `11/3`, `2026-11-03`
- 시간: `14:30`, `오후 3시`, `오전 7시 반`, `3시 20분` (생략하면 09:00)
- 시간이 겹치는 일정을 등록하면 경고를 보여줍니다.
- 데이터는 `~/.scheduler/schedule.json`에 저장됩니다. (`SCHEDULER_FILE` 환경변수로 변경)
- `remind`를 Windows 작업 스케줄러나 cron에 5~10분마다 걸어 두면 알림 용도로 쓸 수 있습니다.
