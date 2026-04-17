# ClaudeMonitor

<img width="413" height="231" alt="image" src="https://github.com/user-attachments/assets/ba1092d0-0d0a-4d7c-89d1-a92750fa30a6" />


Claude Code 세션을 모니터링하는 macOS 오버레이 앱.  
여러 Claude Code 세션을 캐릭터로 화면에 띄워두고, 작업 완료 시 말풍선 알림을 받을 수 있습니다.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)

## Features

- 항상 최상위에 떠있는 오버레이 캐릭터 (모든 Space + 전체화면에서 표시)
- 세션별 커스텀 GIF 아바타
- Claude Code 응답 완료 / 권한 요청 시 말풍선 알림 + 사운드
- 말풍선/캐릭터 클릭 시 해당 세션의 터미널 탭으로 이동
- 드래그로 위치 이동
- 캐릭터 크기 설정 (Small / Medium / Large)
- 다양한 터미널 지원: iTerm2, Terminal.app, cmux, Warp, Ghostty, Kitty, Alacritty, tmux
- Settings UI에서 세션/터미널/크기 설정
- `/monitor` 슬래시 커맨드로 세션 자동 등록

<img width="560" height="544" alt="Vector" src="https://github.com/user-attachments/assets/21e6186e-7960-4262-99ac-7db9bc8c5a96" />


## Install

```bash
git clone https://github.com/jeongchoyi/ClaudeMonitor.git
cd ClaudeMonitor
swift build -c release
.build/release/ClaudeMonitor &
```

> 로그인 시 자동 실행하려면 `System Settings > General > Login Items`에 추가하세요.

## Setup

### 1. Claude Code Hook 설정

`~/.claude/settings.json`에 추가:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/ClaudeMonitor/Scripts/register-hook.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/ClaudeMonitor/Scripts/notify-hook.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/ClaudeMonitor/Scripts/notify-hook.sh"
          }
        ]
      }
    ]
  }
}
```

> `/path/to/ClaudeMonitor/`를 실제 설치 경로로 변경하세요.

- **SessionStart**: 세션 시작 시 자동으로 ClaudeMonitor에 등록됩니다. 세션이 종료되면 자동으로 사라집니다.
- **Stop**: Claude 응답이 완전히 끝났을 때(툴 실행 중/중간 단계엔 fire 안 됨) 말풍선을 띄웁니다. "진짜 다 끝났을 때만" 알림 받고 싶으면 이것만 써도 됩니다.
- **Notification**: Claude가 사용자 입력을 기다릴 때(권한 요청 / 60초 idle) 말풍선을 띄웁니다. 중간에 Allow/Deny 확인 필요한 경우를 놓치지 않으려면 Stop과 함께 쓰세요.

### 2. 터미널 설정

캐릭터 우클릭 → Settings에서 사용 중인 터미널을 선택합니다.

| 터미널 | 탭 전환 | 필요 권한 |
|--------|---------|-----------|
| **iTerm2** | CWD 기반 자동 매칭 | Automation (AppleScript) |
| **Terminal.app** | 탭 이름 기반 매칭 | Automation (AppleScript) |
| **cmux** | 앱 활성화 | 없음 |
| **tmux** | pane CWD 기반 매칭 | 없음 |
| **Warp** | 앱 활성화 | 없음 |
| **Ghostty** | 앱 활성화 | 없음 |
| **Kitty** | 앱 활성화 | 없음 |
| **Alacritty** | 앱 활성화 | 없음 |

**iTerm2/Terminal.app 사용 시:**
처음 클릭할 때 macOS가 자동화 권한을 요청합니다. `System Settings > Privacy & Security > Automation`에서 ClaudeMonitor가 해당 터미널을 제어할 수 있도록 허용하세요.

### 3. 세션 등록

Hook 설정을 완료하면 Claude Code 세션 시작 시 **자동으로 등록**됩니다. 세션 종료 후에는 자동으로 사라집니다.

수동으로 등록하려면:

- **Settings UI**: 캐릭터 우클릭 → Settings → Add Session (수동 등록 세션은 자동 삭제되지 않음)
- **curl**: `curl -s -X POST http://localhost:9877/register -H "Content-Type: application/json" -d '{"name":"my-session","cwd":"/path/to/project"}'`

### 4. 아바타 설정

Settings에서 GIF/PNG/JPG 파일을 선택하면 `~/.claude-monitor/avatars/`에 자동 복사됩니다.
GIF 파일은 애니메이션으로 표시됩니다.

### 5. 캐릭터 크기

Settings의 **Size** 선택에서 `Small` / `Medium` / `Large` 중 선택할 수 있습니다 (기본값: Small).
캐릭터 본체, 이름 라벨, 오버레이 창 크기가 함께 스케일됩니다.

## Usage

| 동작 | 결과 |
|------|------|
| 캐릭터 클릭 | 해당 세션 터미널 활성화 |
| 말풍선 클릭 | 터미널 활성화 + 말풍선 닫기 |
| 드래그 | 위치 이동 |
| 우클릭 / Ctrl+클릭 | 컨텍스트 메뉴 (Settings, New Session, Reset Position, Quit) |

터미널로 전환하면 말풍선이 자동으로 사라집니다.

## API

ClaudeMonitor는 `localhost:9877`에서 HTTP 서버를 실행합니다.

**알림 보내기:**
```bash
curl -X POST http://localhost:9877/notify \
  -H "Content-Type: application/json" \
  -d '{"cwd":"/path/to/project","message":"Build done!"}'
```

**세션 등록:**
```bash
curl -X POST http://localhost:9877/register \
  -H "Content-Type: application/json" \
  -d '{"name":"session-name","cwd":"/path/to/project"}'
```

## Config

설정 파일: `~/.claude-monitor/config.json`  
아바타 저장: `~/.claude-monitor/avatars/`  
앱 아이콘: `~/.claude-monitor/icon.png` (선택사항)

```json
{
  "terminal": "iTerm2",
  "characterSize": "Small",
  "sessions": [
    {
      "name": "my-project",
      "cwdPattern": "/Users/me/projects/my-project",
      "gifPath": "/Users/me/.claude-monitor/avatars/avatar.gif",
      "order": 0
    }
  ]
}
```

- `terminal` 값: `iTerm2`, `Terminal`, `cmux`, `tmux`, `Warp`, `Ghostty`, `Kitty`, `Alacritty`
- `characterSize` 값: `Small`, `Medium`, `Large`
