# 저울 데이터 이전 도구 (구형 저울 → 신형 저울)

구형 저울에서 내보낸 상품(PLU) 데이터는 **EUC-KR(CP949)** 인코딩이라
요즘 프로그램(UTF-8)에서 열면 한글이 `莪탕◆` 처럼 깨져 보입니다.
이 도구는 파일 인코딩을 자동으로 감지해서 반대 인코딩으로 변환해 줍니다.

- EUC-KR 파일 → `파일명_utf8.csv` 생성
- UTF-8 파일 → `파일명_euckr.csv` 생성

## 사용법 (Windows)

### 방법 1 — 드래그 앤 드롭 (가장 쉬움)

1. `convert-encoding.ps1` 과 `drag-drop-convert.bat` 두 파일을 같은 폴더에 내려받기
2. 변환할 CSV/TXT 파일을 **`drag-drop-convert.bat` 위로 끌어다 놓기**
3. 같은 폴더에 변환된 파일이 생성됨

### 방법 2 — PowerShell 명령

```powershell
# 자동 감지 변환
powershell -ExecutionPolicy Bypass -File .\convert-encoding.ps1 -InputFile "상품목록.csv"

# 방향 지정
powershell -ExecutionPolicy Bypass -File .\convert-encoding.ps1 -InputFile "상품목록.csv" -Mode ToUtf8
powershell -ExecutionPolicy Bypass -File .\convert-encoding.ps1 -InputFile "상품목록.csv" -Mode ToEucKr

# BOM 없는 UTF-8이 필요한 경우
powershell -ExecutionPolicy Bypass -File .\convert-encoding.ps1 -InputFile "상품목록.csv" -Mode ToUtf8 -NoBom
```

## 작업 순서 (사무실에서)

1. **구형 저울에서 상품 데이터를 파일로 내보내기** (넷츠매니져 또는 저울 프로그램 사용)
   - ⚠️ 내보낸 파일을 엑셀로 열어서 **다시 저장하지 말 것** — 원본 그대로 보관
2. 이 도구로 파일을 변환 (또는 파일을 Claude 세션에 올려서 변환 요청)
3. 신형 저울의 PLU 관리 프로그램에서 요구하는 형식(열 순서, 인코딩)에 맞춰 가져오기

## 주의사항

- 화면에서 깨져 보여도 **파일 자체가 EUC-KR이면 데이터는 살아있습니다.** 변환하면 정상 복구됩니다.
- 파일 안에 이미 `�` 또는 `?` 로 저장된 글자는 복구 불가 — 구형 저울에서 다시 내보내야 합니다.
- UTF-8 → EUC-KR 변환 시 EUC-KR에 없는 글자(이모지, 특수문자)는 `?` 로 바뀝니다 (경고 표시됨).
