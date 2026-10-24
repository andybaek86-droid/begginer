#!/usr/bin/env python3
"""스케줄러 비서 - 일정 등록/조회/알림 CLI (표준 라이브러리만 사용)."""
import argparse
import json
import os
import re
import sys
from datetime import date, datetime, time, timedelta

DATA_FILE = os.environ.get(
    "SCHEDULER_FILE", os.path.join(os.path.expanduser("~"), ".scheduler", "schedule.json")
)
WEEKDAYS = "월화수목금토일"


def load():
    if not os.path.exists(DATA_FILE):
        return []
    with open(DATA_FILE, encoding="utf-8") as f:
        return json.load(f)


def save(items):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=2)


def parse_date(text, today):
    text = text.strip()
    fixed = {"오늘": 0, "내일": 1, "모레": 2}
    if text in fixed:
        return today + timedelta(days=fixed[text])
    m = re.fullmatch(r"(다음주|담주)?\s*([월화수목금토일])(요일)?", text)
    if m:
        target = WEEKDAYS.index(m.group(2))
        if m.group(1):  # 다음주: 다음 주 월요일 기준으로 해당 요일
            return today - timedelta(days=today.weekday()) + timedelta(days=7 + target)
        return today + timedelta(days=(target - today.weekday()) % 7)
    m = re.fullmatch(r"(\d{4})[-./](\d{1,2})[-./](\d{1,2})", text)
    if m:
        return date(*map(int, m.groups()))
    m = re.fullmatch(r"(\d{1,2})[-./월]\s*(\d{1,2})일?", text)
    if m:
        mo, d = map(int, m.groups())
        result = date(today.year, mo, d)
        return result if result >= today else date(today.year + 1, mo, d)
    raise ValueError(f"날짜를 이해하지 못했어요: '{text}'")


def parse_time(text):
    text = text.strip()
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", text)
    if m:
        return time(int(m.group(1)), int(m.group(2)))
    m = re.fullmatch(r"(오전|오후)?\s*(\d{1,2})시\s*(?:(\d{1,2})분|(반))?", text)
    if m:
        ampm, h, mi, half = m.groups()
        h = int(h)
        mi = 30 if half else int(mi or 0)
        if ampm == "오후" and h < 12:
            h += 12
        if ampm == "오전" and h == 12:
            h = 0
        return time(h, mi)
    raise ValueError(f"시간을 이해하지 못했어요: '{text}'")


def parse_when(tokens, now):
    """'내일 오후 3시' / '2026-11-01 14:30' 같은 토큰 목록을 datetime으로."""
    tokens = list(tokens)
    if not tokens:
        raise ValueError("날짜/시간을 입력해 주세요. 예: 내일 오후 3시")
    # 첫 토큰(다음주 월요일은 두 토큰)을 날짜로, 나머지를 시간으로 해석
    for n in (2, 1):
        if len(tokens) >= n:
            try:
                d = parse_date(" ".join(tokens[:n]), now.date())
            except ValueError:
                continue
            rest = " ".join(tokens[n:])
            t = parse_time(rest) if rest else time(9, 0)
            return datetime.combine(d, t)
    raise ValueError(f"날짜를 이해하지 못했어요: '{' '.join(tokens)}'")


def fmt(item):
    s = datetime.fromisoformat(item["start"])
    e = s + timedelta(minutes=item["minutes"])
    mark = "✔" if item["done"] else " "
    wd = WEEKDAYS[s.weekday()]
    line = f"[{mark}] #{item['id']:<3} {s:%m/%d}({wd}) {s:%H:%M}-{e:%H:%M}  {item['title']}"
    return line + (f"  - {item['note']}" if item.get("note") else "")


def show(items, header):
    print(header)
    if not items:
        print("  (일정 없음)")
    for it in sorted(items, key=lambda i: i["start"]):
        print(" ", fmt(it))


def overlaps(a, b):
    a0 = datetime.fromisoformat(a["start"])
    b0 = datetime.fromisoformat(b["start"])
    return a0 < b0 + timedelta(minutes=b["minutes"]) and b0 < a0 + timedelta(minutes=a["minutes"])


def cmd_add(args, now):
    items = load()
    start = parse_when(args.when, now)
    item = {
        "id": max((i["id"] for i in items), default=0) + 1,
        "title": args.title,
        "start": start.isoformat(timespec="minutes"),
        "minutes": args.minutes,
        "note": args.note or "",
        "done": False,
    }
    clashes = [i for i in items if not i["done"] and overlaps(item, i)]
    items.append(item)
    save(items)
    print("등록했어요:", fmt(item))
    for c in clashes:
        print("⚠ 겹치는 일정:", fmt(c))


def cmd_list(args, now):
    items = load()
    if args.cmd == "today":
        items = [i for i in items if datetime.fromisoformat(i["start"]).date() == now.date()]
        show(items, f"오늘({now:%m/%d}) 일정")
    elif args.cmd == "week":
        end = now.date() + timedelta(days=7)
        items = [i for i in items if now.date() <= datetime.fromisoformat(i["start"]).date() < end]
        show(items, "앞으로 7일 일정")
    else:
        if not args.all:
            items = [i for i in items if not i["done"] and datetime.fromisoformat(i["start"]) >= now]
        show(items, "다가오는 일정" if not args.all else "전체 일정")


def cmd_change(args, now):
    items = load()
    target = next((i for i in items if i["id"] == args.id), None)
    if not target:
        sys.exit(f"#{args.id} 일정을 찾을 수 없어요.")
    if args.cmd == "done":
        target["done"] = True
        print("완료 처리:", fmt(target))
    else:
        items.remove(target)
        print("삭제:", fmt(target))
    save(items)


def cmd_remind(args, now):
    """지금부터 N분 안에 시작하는 일정을 알려줌 (작업 스케줄러/cron에 걸어 쓰기)."""
    soon = [
        i for i in load()
        if not i["done"] and now <= datetime.fromisoformat(i["start"]) <= now + timedelta(minutes=args.within)
    ]
    show(soon, f"{args.within}분 안에 시작하는 일정")


def build_parser():
    p = argparse.ArgumentParser(description="스케줄러 비서")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add", help='일정 추가: add "팀 회의" 내일 오후 3시')
    a.add_argument("title")
    a.add_argument("when", nargs="+", help="예: 내일 오후 3시 / 금 14:30 / 2026-11-01 10:00")
    a.add_argument("-m", "--minutes", type=int, default=60, help="소요 시간(분), 기본 60")
    a.add_argument("-n", "--note", help="메모")
    l = sub.add_parser("list", help="다가오는 일정")
    l.add_argument("--all", action="store_true", help="지난/완료 일정 포함")
    sub.add_parser("today", help="오늘 일정")
    sub.add_parser("week", help="7일 일정")
    for name, h in (("done", "완료 처리"), ("rm", "삭제")):
        c = sub.add_parser(name, help=h)
        c.add_argument("id", type=int)
    r = sub.add_parser("remind", help="곧 시작할 일정 알림")
    r.add_argument("--within", type=int, default=30, help="분 단위, 기본 30")
    return p


def main(argv=None, now=None):
    args = build_parser().parse_args(argv)
    now = now or datetime.now()
    try:
        {"add": cmd_add, "list": cmd_list, "today": cmd_list, "week": cmd_list,
         "done": cmd_change, "rm": cmd_change, "remind": cmd_remind}[args.cmd](args, now)
    except ValueError as e:
        sys.exit(str(e))


if __name__ == "__main__":
    main()
