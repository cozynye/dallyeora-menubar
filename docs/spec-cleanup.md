# 정리하기 — 설계 스펙

작성일: 2026-11-06
기반: `docs/spec.md` (v0.3.0 시점의 앱 구조)

## 1. 목적

CPU나 메모리 사용률이 높을 때 어떤 앱이 얼마나 쓰는지 **한국어로 알아볼 수 있게** 보여 주고, 안 쓰는 앱을 **그 자리에서 끌 수 있게** 한다. 활성 상태 보기는 영어 프로세스 이름이 수십 줄 나와서 뭘 꺼야 하는지 알기 어렵다는 문제를 푼다.

## 2. 범위

### 포함
- 메뉴 항목 "정리하기…"와 그걸 누르면 뜨는 창 하나
- 창 안에서 CPU / 메모리 전환, 사용량 순 목록(최대 15줄 + "그 외" 1줄), 2초 갱신
- 보조 프로세스를 앱 단위로 묶기, 한국어 이름·설명·종류 표시
- 내 앱 일반 종료, 안 꺼지면 강제 종료
- 시스템·다른 사용자 프로세스는 "macOS 시스템" 한 줄로 합산

### 제외
- 시스템 프로세스의 개별 수치 (권한 없이는 읽을 수 없음, 3.1 참고)
- 앱이 아닌 프로세스 종료 (백그라운드 서비스, 터미널에서 띄운 node 등)
- 사전 편집 UI, 영어 UI, 자동 알림이나 캐릭터의 제안, 메모리 비우기(purge), 로그인 항목 관리, 설정 저장(창의 지표 선택은 저장하지 않는다)

## 3. 동작

### 3.1 읽을 수 있는 것 (사전 조사로 확인)
관리자 권한 없이 `libproc`/`sysctl`로 읽을 수 있는 범위는 다음과 같다.

| 대상 | 이름·경로·부모 pid·uid | 메모리(phys_footprint)·CPU 시간 |
|---|---|---|
| 내 계정 프로세스 | 읽힘 | 읽힘 (`proc_pid_rusage`) |
| 다른 사용자(root, _windowserver 등) | 읽힘 (`sysctl KERN_PROC_PID`, `proc_pidpath`) | 읽히지 않음 |

`ps`와 활성 상태 보기는 root 권한을 가진 특수 프로그램이라 다르다. 사설 API(`responsibility_get_pid_responsible_for_pid` 등)는 쓰지 않는다.

### 3.2 메뉴
기존 메뉴에 항목 하나와 구분선을 추가한다.
```
개복치                 CPU 42%
스트레스로 위독
───────────────
정리하기…
───────────────
캐릭터 ▸ / 말투 ▸ / 지표 ▸
───────────────
종료                       ⌘Q
```
"정리하기…"를 누르면 창을 보여 주고 `NSApp.activate(ignoringOtherApps:)`로 앞에 가져온다(메뉴 막대 전용 앱은 그냥 두면 창이 뒤에 뜬다). 창은 한 개만 쓰고, 이미 열려 있으면 앞으로만 가져온다.

### 3.3 창
- 제목 "정리하기", 기본 크기 560×440, 최소 480×360, 크기 조절 가능.
- 맨 위: 세그먼트 컨트롤 `CPU | 메모리`. 처음 열 때 값은 메뉴 막대에서 고른 지표. 여기서 바꿔도 메뉴 막대 지표나 설정은 바뀌지 않는다.
- 그 아래 한 줄 요약: `지금 메모리를 많이 쓰는 것 · 전체 85%` (지표 이름과 현재 전체 사용률).
- 목록: 선택한 지표 기준 내림차순, 최대 15줄. 16개 이상이면 마지막에 `그 외 N개` 한 줄로 나머지를 합산한다.
- 한 줄 구성:
  ```
  [아이콘]  제목                                 사용량    종류 배지   [버튼]
            설명 한 줄 (왜 올라가는지, 기다리면 내려가는지)
  ```
  - 아이콘: 앱은 그 앱 아이콘, 나머지는 톱니 모양 기호.
  - 사용량: 메모리는 `3.2 GB` / `410 MB` / `12 KB`(1024 기준, GB는 소수 한 자리), CPU는 `37%`. CPU는 두 번째 측정 전까지 `측정 중…`.
  - 종류 배지: `끌 수 있음` / `내 백그라운드` / `시스템` / `그 외`.
  - 버튼: `끌 수 있음`인 줄에만 `종료`. 누르면 `종료 중…`으로 바뀌고 비활성. 5초 뒤에도 프로세스가 살아 있으면 `강제 종료`로 바뀌며 다시 활성. 종료 요청 자체가 실패하면 바로 `강제 종료`. 앱이 사라지면 다음 갱신 때 줄이 없어진다.
- 갱신: 창이 보이는 동안 2초마다. 열자마자 한 번 읽고 1초 뒤 한 번 더 읽어 CPU 값을 빨리 채운다. 창을 닫으면 타이머를 멈춘다.
- 읽기에 실패하면(스냅샷이 비면) 목록 자리에 `프로세스 정보를 읽을 수 없습니다`를 보여 준다.
- 달려라 메뉴바 자신은 목록에서 뺀다.

### 3.4 묶기 규칙
입력은 프로세스 표본(pid, ppid, uid, 이름, 경로, footprint 바이트, CPU 누적 시간 ns)의 목록이다. 순서대로 적용한다.

1. 내 pid는 버린다.
2. uid가 내 uid와 다르면 **시스템** 묶음으로 보낸다. 수치는 없고 개수만 남긴다(설명 문구가 고정이라 이름은 쓰지 않는다).
3. 경로에서 **가장 바깥의 `.app`** 까지를 앱 번들 경로로 본다. 예: `/Applications/Google Chrome.app/Contents/Frameworks/…/Google Chrome Helper (Renderer).app/Contents/MacOS/…` → `/Applications/Google Chrome.app`. 있으면 그 번들로 묶는다.
4. 경로에 `.app`이 없으면 ppid를 따라 올라가며(최대 10단계, pid 1에서 멈춤) 3번 규칙에 맞는 조상을 찾는다. 찾으면 그 번들로 묶는다. 예: Cursor가 띄운 `/opt/homebrew/bin/node` → Cursor, 터미널에서 띄운 `python` → 터미널.
5. 그래도 없으면 **이름**으로 묶는다. 예: `mds_stores` 3개 → 한 줄, `com.apple.WebKit.WebContent` 여러 개 → 한 줄.

앱 묶음의 **대표 pid**는 경로가 `<번들>/Contents/MacOS/` 바로 아래인 프로세스다. 없으면 가장 작은 pid. 종료 명령은 대표 pid에 보낸다.

### 3.5 사용량 계산
- 메모리: 묶음에 속한 프로세스의 `phys_footprint` 합. 활성 상태 보기 "메모리" 열과 같은 기준.
- CPU: 직전 스냅샷과 비교해 **pid별** CPU 시간 차이를 더한다. 직전에 없던 pid는 0으로 친다(새 프로세스의 누적 시간을 한 번에 더하지 않기 위해). `Σ Δcpu시간 / Δ경과시간 / 코어 수 × 100`으로 메뉴 막대와 같은 "전체 대비 %"가 된다. CPU 시간은 Mach 단위라 읽는 쪽에서 `mach_timebase_info`로 ns로 바꿔 넘긴다.
- 시스템 줄: 메모리 = `전체 사용 바이트 − 내 묶음 footprint 합`, CPU = `전체 CPU% − 내 묶음 CPU% 합`. 둘 다 0 미만이면 0. 전체 값은 기존 `CPUTicks`/`MemoryPages`를 스냅샷과 같은 시점에 읽어 쓴다. footprint와 "사용된 메모리"는 기준이 달라 근사치이며, 설명 줄에 그렇게 적는다.
- 그 외 줄: 15위 밖 묶음의 합.

### 3.6 한국어 사전
- 항목: 매칭 키(번들 ID 정확 일치 / 프로세스 이름 정확 일치 / 이름 접두사), 한국어 제목, 한 줄 설명.
- 찾는 순서: 앱 묶음은 번들 ID → 번들 이름. 이름 묶음은 이름 정확 일치 → 접두사 → 패턴 → 모름.
- 사전에 없을 때:
  - 앱 묶음: 제목은 macOS가 주는 현지화된 앱 이름(`FileManager.displayName(atPath:)`, 예: `미리보기`), 설명은 `Dock이나 메뉴 막대에 보이는 앱. 안 쓰면 꺼도 된다.`
  - 이름 묶음, 패턴: `Helper`/`Renderer`/`Plugin` 포함 → `어떤 앱의 보조 프로세스. 그 앱을 닫으면 함께 사라진다.`; `d`나 `agent`로 끝남 또는 `com.apple.`로 시작 → `macOS 백그라운드 서비스. 보통 잠시 뒤 저절로 내려간다.`
  - 그래도 모르면 제목은 이름 그대로, 설명은 `무엇인지 알 수 없는 프로세스.` 숨기지 않고 모른다고 표시한다.
- 시스템 줄 설명: `시스템 프로세스 N개 (WindowServer, kernel_task 등). 권한이 없어 세부는 볼 수 없고 끌 수도 없다. 메모리는 근사치다.`
- 처음 넣는 항목은 100개 이상으로, 다음을 반드시 포함한다.
  - 내 계정으로 도는 macOS 구성 요소: Dock, Finder, Spotlight, ControlCenter, NotificationCenter, WindowManager, SystemUIServer, loginwindow, mdworker_shared, corespotlightd, photoanalysisd, photolibraryd, mediaanalysisd, bird, cloudd, cloudphotod, nsurlsessiond, com.apple.WebKit.WebContent, com.apple.WebKit.Networking, com.apple.WebKit.GPU, QuickLookUIService, suggestd, knowledgeconstructiond, siriknowledged, assistantd, accountsd, identityservicesd, imagent, sharingd, rapportd, secd, trustd, cfprefsd, distnoted, UserEventAgent, lsd, tccd
  - 시스템 줄 설명과 "그 외"를 위해 이름만 아는 것: kernel_task, WindowServer, launchd, mds, mds_stores, backupd, softwareupdated, syspolicyd, XprotectService, coreaudiod, opendirectoryd, runningboardd
  - 흔한 앱(번들 ID): Safari, Chrome, Firefox, Edge, Brave, Whale, Arc, VS Code, Cursor, Xcode, Simulator, Terminal, iTerm2, Docker Desktop, Slack, Discord, Notion, 카카오톡, Zoom, Teams, Spotify, Music, Figma, Postman, IntelliJ, Word, Excel, PowerPoint, Photoshop, ChatGPT, Claude, 1Password, Dropbox, Google Drive, Photos, Mail, Notes, Calendar, Preview, Activity Monitor
  - 이름으로 뜨는 개발 도구: node, python/Python, java, ruby, swift-frontend, clang, SourceKitService, com.docker.backend, com.docker.virtualization, qemu-system-aarch64, ollama, gradle, rustc, cargo
- 설명은 사용자가 바로 행동할 수 있게 쓴다. "왜 올라가는지"와 "기다리면 내려가는지 / 끄려면 무엇을 닫아야 하는지"를 한 줄에 담는다. 예:
  - Google Chrome: `웹 브라우저. 탭 하나가 프로세스 하나라 탭이 많으면 메모리를 많이 쓴다. 안 보는 탭을 닫으면 줄어든다.`
  - com.apple.WebKit.WebContent: `Safari(또는 WebKit을 쓰는 앱)의 웹 페이지. Safari 탭을 닫으면 줄어든다.`
  - mdworker_shared: `Spotlight 검색 색인. 새 파일이 많이 생기면 한동안 바쁘다가 저절로 내려간다.`
  - photoanalysisd: `사진 앱의 얼굴·사물 분석. 사진을 많이 넣은 뒤 며칠간 돌 수 있다. 전원에 연결해 두면 밤에 끝난다.`
  - kernel_task: `macOS 커널. CPU가 높아 보이면 대개 발열을 막으려고 일부러 CPU를 점유하는 것이다. 끌 수 없다.`
  - Docker Desktop: `컨테이너 실행 환경. 켜 두면 가상 머신이 메모리를 계속 잡는다. 컨테이너를 안 쓸 때는 끄는 게 좋다.`

### 3.7 종료 가능 판정
`끌 수 있음`은 다음을 모두 만족하는 앱 묶음이다.
- 대표 pid로 `NSRunningApplication`을 얻을 수 있다.
- `activationPolicy`가 `.regular` 또는 `.accessory`다 (Dock이나 메뉴 막대에 보이는 앱). `.prohibited`(백그라운드 전용)는 `내 백그라운드`로 표시만 한다.

Finder, Dock, Spotlight, 제어 센터처럼 `.app` 번들로 돌아가는 **macOS 구성 요소는 사전에 보호 표시**를 두어 `activationPolicy`와 무관하게 `시스템` 배지로 보여 주고 버튼을 붙이지 않는다(Finder는 꺼도 바로 다시 켜지지만 사용자가 당황한다).

종료는 `terminate()`(⌘Q와 같아서 저장하지 않은 문서가 있으면 그 앱이 묻는다), 강제 종료는 `forceTerminate()`다. 강제 종료는 저장하지 않은 작업을 잃을 수 있으므로 누르면 `NSAlert`로 한 번 확인한다: 제목 `"<앱 이름>"을(를) 강제 종료할까요?`, 본문 `저장하지 않은 작업은 사라집니다.`, 버튼 `강제 종료` / `취소`. `terminate()`가 macOS 권한 요청 창을 띄우지 않는지는 미검증이라 구현 첫 단계에서 실제로 눌러 확인한다.

## 4. 구조

기존 원칙대로 AppKit 없는 로직은 `DallyeoraCore`에, 화면은 `Dallyeora`에 둔다. 창 내용은 SwiftUI로 그리고 `NSHostingView`로 `NSWindow`에 넣는다. 표 형태 UI는 `NSTableView`보다 코드가 훨씬 짧고 macOS 14 이상은 `@Observable`을 쓸 수 있다. 메뉴 막대 쪽은 그대로 AppKit이다.

### DallyeoraCore (추가)
| 구성 요소 | 책임 | 의존 |
|---|---|---|
| `ProcessSample` | pid, ppid, uid, name, path, footprintBytes, cpuTimeNanos | 없음 |
| `ProcessSnapshot` | `uptime: TimeInterval`과 `samples: [ProcessSample]` | `ProcessSample` |
| `ProcessReader` | `proc_listallpids` → pid마다 `sysctl KERN_PROC_PID`(ppid, uid), `proc_pidpath`, 내 uid면 `proc_pid_rusage`(footprint, CPU 시간을 timebase로 ns 변환). 이름은 경로의 마지막 요소를 쓰고, 경로를 못 읽으면 `p_comm`(16자에서 잘림)을 쓴다 | Darwin |
| `ProcessGroup` | `id`, `kind`(`.app(bundlePath, mainPID)` / `.background(name)` / `.system(count)`), `pids`, `footprintBytes`, `cpuTimeNanos` | 없음 |
| `AppBundleInfo` | 번들 경로에서 `Bundle(path:)`로 번들 ID, `FileManager.displayName(atPath:)`로 현지화 이름을 읽는다 | Foundation |
| `ProcessGrouper` | 3.4의 묶기 규칙. `appBundlePath(of:)`, `group(_:currentUID:selfPID:)` | `ProcessGroup` |
| `UsageRanker` | 3.5의 계산. 직전 pid별 CPU 시간, 경과 시간, 코어 수, 전체 CPU%, 전체 메모리 바이트를 받아 정렬된 `RankedRow` 목록을 만든다. `RankedRow`는 `group`(그 외 줄은 nil), `kind`(`.app` / `.background` / `.system` / `.others`), `memoryBytes`, `cpuPercent: Double?`를 가진다 | `ProcessGroup`, `Metric` |
| `ProcessCatalog` | 3.6의 사전과 폴백. `describe(group, bundleID:, localizedName:) -> ProcessDescription(title, summary, source, isProtected)` | `ProcessGroup` |
| `UsageFormat` | 바이트와 퍼센트 문자열 | 없음 |
| `MemoryUsage.usedBytes(_:pageSize:)` | 기존 페이지 수를 바이트로 | 기존 `MemoryPages` |

### Dallyeora (추가)
| 구성 요소 | 책임 |
|---|---|
| `CleanupModel` (`@MainActor @Observable`) | 스냅샷 → 묶기 → 순위 → 설명을 합쳐 화면용 행을 만든다. 2초 타이머, 종료/강제 종료 상태(5초 대기) 관리 |
| `AppTerminator` | `NSRunningApplication`으로 끌 수 있는지 판정, `terminate`, `forceTerminate`, 살아 있는지 확인, 아이콘·번들 ID·현지화 이름 제공 |
| `CleanupView` (SwiftUI) | 세그먼트, 요약 줄, 목록, 행, 버튼 |
| `CleanupWindowController` | `NSWindow` 생성·재사용, 열 때 활성화, 닫을 때 타이머 정지 |
| `StatusItemController` (수정) | "정리하기…" 메뉴 항목 추가 |

## 5. 테스트

`swift test`로 돌아가는 Core 테스트:
- `ProcessGrouper`: 크롬 헬퍼 경로 → 크롬 번들; node(ppid 체인) → Cursor; 조상 없는 `mds_stores` 3개 → 이름 묶음 1개; 다른 uid → 시스템 1묶음에 개수; 내 pid 제외; ppid가 순환해도 10단계에서 멈춤; 대표 pid 선택.
- `UsageRanker`: pid별 Δ로 CPU% 계산(새 pid는 0); 메모리 합; 시스템 잔여가 음수면 0; 지표별 정렬; 16개 이상이면 "그 외" 합산; 직전 스냅샷이 없으면 CPU nil.
- `ProcessCatalog`: 번들 ID 일치, 이름 일치, 접두사, Helper 패턴, d/agent 패턴, 모름(제목은 이름 그대로); 사전 항목이 100개 이상이고 3.6의 필수 목록이 모두 들어 있다.
- `UsageFormat`: 바이트 경계값(1023 B, 1 KB, 1 MB, 1.5 GB), 퍼센트 반올림.
- `ProcessReader`: 실제로 읽어서 내 프로세스가 1개 이상이고 footprint > 0, 다른 uid 프로세스가 있고 그것들의 footprint는 0.

눈으로 확인할 것(화면 캡처 권한이 없어 사용자가 본다): 창이 앞으로 뜨는지, 2초마다 바뀌는지, 종료 버튼으로 앱이 꺼지는지, 저장 안 한 문서가 있을 때 그 앱이 묻는지, 5초 뒤 강제 종료로 바뀌는지, 권한 요청 창이 뜨는지.

## 6. 한계 (README에 그대로 적는다)
- 시스템 프로세스는 개별로 볼 수 없고 한 줄로 합쳐 보인다.
- 메모리 합이 메뉴 막대의 사용률과 정확히 맞지 않는다.
- 사전에 없는 프로세스는 영어 이름 그대로 또는 "알 수 없음"으로 보인다.
- 앱이 아닌 것은 끌 수 없다. 터미널에서 띄운 것은 터미널을 끄면 함께 꺼진다.
- 창은 한국어만 지원한다.
