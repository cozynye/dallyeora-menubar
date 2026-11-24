# 상태머신 지도

이 앱에서 "지금 어떤 상태인가"를 가지고 있는 곳을 전부 모은 문서다. 전이 규칙을 Core의 struct로 옮겨 테스트를 붙인 것과 일부러 그대로 둔 것을 나눠 적었고, 그대로 둔 것은 어떤 변수가 상태 노릇을 하는지 적어 두었다. 상태를 건드리는 코드를 고치기 전에 여기서 해당 항목을 먼저 확인하고, 상태나 전이를 바꾸면 이 문서도 함께 고친다.

명시적인 머신은 모두 같은 모양이다. `Sources/DallyeoraCore`에 struct가 있고, 일어난 일을 메서드로 받아 상태를 바꾼 뒤 앱 쪽이 할 일(타이머를 걸지, 무슨 문구를 띄울지)을 반환값으로 알려 준다. 타이머와 AppKit 호출은 `Sources/Dallyeora`에 남는다.

## 명시적으로 만든 것

| 머신 | Core | 앱에서 쓰는 곳 | 테스트 |
|---|---|---|---|
| 화면 꺼짐 | `ActivityState` | `ActivityMonitor` | `ActivityStateTests` |
| 대사 잠깐 보이기 | `PhraseFlash` | `StatusItemController` | `PhraseFlashTests` |
| 사용률 측정 여부 | `UsageSampler.isMeasured` | `StatusItemController.render` | `UsageSamplerTests` |
| 정리하기 창 갱신 | `Cleanup/CleanupRunState` | `CleanupWindowController` | `CleanupRunStateTests` |
| 앱 종료 흐름 | `Cleanup/QuitTracker` | `CleanupModel` | `QuitTrackerTests` |

### 화면 꺼짐 (`ActivityState`)

```
입력: screensAsleep, sessionInactive

active   둘 다 아니다. 측정 타이머와 그리기 타이머가 돈다.
paused   하나라도 참이다. 두 타이머를 끊는다.
```

`handle(_:)`은 `isActive`가 바뀌었을 때만 true를 돌려주고, `StatusItemController.setActive`가 타이머를 걸거나 끊은 뒤 정리하기 창에도 같은 신호를 넘긴다.

### 대사 잠깐 보이기 (`PhraseFlash`)

```
hidden    대사가 안 보인다.
flashing  단계가 바뀌어 3초 동안 보이는 중.

hidden   → flashing   shouldFlash(tier:)가 직전과 다른 단계를 받음 (pinned가 아닐 때)
flashing → flashing   그사이 단계가 또 바뀜. 앱이 타이머를 다시 건다.
flashing → hidden     expire() (3초 타이머) 또는 reset() (캐릭터 변경)
```

메뉴 막대에 대사가 실제로 보이는 조건은 `settings.showsPhrase || flash.isFlashing`이다. "메뉴 막대에 대사 표시"를 켠 동안에는 `pinned: true`로 불러서 단계만 기록하고 띄우지 않는다. 비교할 직전 단계가 없으면(켠 직후, `reset()` 직후) 띄우지 않는다. 지표를 바꿔서 단계가 달라진 경우는 띄운다.

### 사용률 측정 여부 (`UsageSampler.isMeasured`)

CPU는 두 번 재야 값이 나와서 첫 측정 뒤의 0%는 잰 값이 아니다. `render()`는 `isMeasured`가 true일 때만 `PhraseFlash`에 단계를 넘긴다. 이 검사가 없으면 켜자마자 0%의 단계가 기록되고 0.25초 뒤 실제 값이 들어오면서 대사가 뜬다. 화면에 그리는 값은 측정 전에도 0%를 그대로 쓴다.

### 정리하기 창 갱신 (`CleanupRunState`)

```
입력: isOpen, isMiniaturized, screenActive

running  창이 열려 있고, 최소화되지 않았고, 화면이 켜져 있다. 2초마다 프로세스를 읽는다.
stopped  그 밖. 읽지 않는다.
```

`CleanupWindowController.handle(_:)`이 유일한 입구이고, `shouldRun`이 바뀔 때만 `model.start()`나 `model.stop()`을 부른다. 이미 떠 있는 창을 다시 불러도 다시 시작하지 않는다. 최소화한 창을 메뉴나 단축키로 부르면 `windowOpened`가 최소화를 풀어 준다.

### 앱 종료 흐름 (`QuitTracker`)

줄 id(앱 묶음)마다 하나씩 돈다.

```
idle       "종료" 버튼
requested  "종료 중…" (눌리지 않음)
force      "강제 종료" 버튼

idle      → requested   request(sent: true). 10초 타이머에 넘길 Ticket을 돌려준다.
idle      → force       request(sent: false). "종료 요청을 보내지 못했습니다"
requested → idle        rowsDidChange에서 줄이 사라짐. "종료했습니다"
requested → force       deadlinePassed(isRunning: true). "응답이 없어 강제 종료 버튼으로 바꿨습니다"
requested → idle        deadlinePassed(isRunning: false). "종료했습니다"
force     → idle        forceQuit(done:) 또는 줄이 사라짐
전부      → idle        reset() (창을 닫음). 알리지 않는다.
```

`Ticket`에는 요청마다 올라가는 세대 번호가 들어 있다. 10초 타이머는 취소하지 않고 두는데, 그사이 줄이 정리됐거나 같은 줄에 새 요청이 생겼으면 표가 맞지 않아 `deadlinePassed`가 nil을 돌려준다. 종료한 앱을 다시 켜서 10초 안에 또 종료를 눌러도 옛 타이머가 새 요청을 건드리지 않는 것은 이 번호 때문이다.

## 그대로 둔 것

| 상태 | 가지고 있는 곳 | 그대로 둔 이유 |
|---|---|---|
| 그리기 루프 | `StatusItemController`의 `sampleTimer`, `frameTimer` (nil이면 멈춤) | 켜고 끄는 판단은 `ActivityState`가 하고 여기는 타이머만 든다. |
| 줄 순서 고정 | `CleanupModel`의 `isHovering`, `frozenRowIDs`, `frozenMemberPIDs` | 순서를 만드는 판단은 `StableOrder`에 있고 테스트가 있다. |
| 상태 줄 | `CleanupModel`의 `notice`, `noticeTimer` | 5초 뒤 지우는 타이머 하나다. 새 결과가 오면 시간을 다시 센다. |
| 프로세스별 CPU 측정 | `CleanupModel`의 `previous`, `current` | 직전 스냅샷이 없으면 "측정 중…"이다. 창을 다시 열면 첫 1초는 닫혀 있던 동안의 평균이 나온다. |
| 지표 동기화 | `CleanupModel.metric`과 `Settings.metric` | 서로를 바꾸지만 값이 같으면 양쪽 다 멈춘다. |
| 프로세스 하나 종료 | `CleanupModel.quit(member:)`의 0.5초 타이머 | 한 번 확인하고 끝나서 남는 상태가 없다. |
| 새 버전 확인 | `UpdateChecker`의 `isChecking`, UserDefaults의 `lastUpdateCheck`, `latestKnownVersion` | 판단은 `UpdateCheck`에 있다. 확인에 실패한 뒤에는 설정을 아무거나 바꿔도 다시 시도한다. |
| 로그인 항목 | `SMAppService.mainApp.status` | 시스템이 주인이라 앱은 저장하지 않고 메뉴를 열 때마다 읽는다. |
| 전역 단축키 | `GlobalHotKey`의 `hotKey` (nil이면 미등록) | 켤 때 한 번 등록하고 끝날 때까지 둔다. |
| 설정 | `Settings` (UserDefaults) | 값이 바뀌면 `Settings.didChange`를 보내고, 듣는 쪽이 다시 그린다. |
