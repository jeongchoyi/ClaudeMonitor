# ClaudeMonitor

Claude Code 세션을 모니터링하는 macOS 오버레이 앱.  
여러 Claude Code 세션을 캐릭터로 화면에 띄워두고, 작업 완료 시 말풍선 알림을 받을 수 있습니다.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)

## Features

- 항상 최상위에 떠있는 오버레이 캐릭터 (모든 Space + 전체화면에서 표시)
- 세션별 커스텀 GIF 아바타
- Claude Code 작업 완료 시 말풍선 알림 + 사운드
- 말풍선/캐릭터 클릭 시 해당 세션의 터미널 탭으로 이동
- 드래그로 위치 이동
- 다양한 터미널 지원: iTerm2, Terminal.app, Warp, Ghostty, Kitty, Alacritty, tmux
- Settings UI에서 세션/터미널 설정
- `/monitor` 슬래시 커맨드로 세션 자동 등록

## Install

### 소스에서 빌드

```bash
git clone https://github.com/choyi-macarong/ClaudeMonitor.git
cd ClaudeMonitor
swift build -c release
```

빌드된 바이너리 실행:
```bash
.build/release/ClaudeMonitor &
```

### 릴리즈 바이너리 다운로드

[Releases](https://github.com/choyi-macarong/ClaudeMonitor/releases) 페이지에서 최신 바이너리를 다운로드하거나:

```bash
# dist/ 에 포함된 바이너리 사용
tar -xzf dist/ClaudeMonitor-macos-arm64.tar.gz
./ClaudeMonitor &
```

> 로그인 시 자동 실행하려면 `System Settings > General > Login Items`에 추가하세요.

## Setup

### 1. Claude Code Hook 설정

`~/.claude/settings.json`에 추가:

```json
{
  "hooks": {
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

### 2. 터미널 설정

캐릭터 우클릭 → Settings에서 사용 중인 터미널을 선택합니다.

| 터미널 | 탭 전환 | 필요 권한 |
|--------|---------|-----------|
| **iTerm2** | CWD 기반 자동 매칭 | Automation (AppleScript) |
| **Terminal.app** | 탭 이름 기반 매칭 | Automation (AppleScript) |
| **tmux** | pane CWD 기반 매칭 | 없음 |
| **Warp** | 앱 활성화 | 없음 |
| **Ghostty** | 앱 활성화 | 없음 |
| **Kitty** | 앱 활성화 | 없음 |
| **Alacritty** | 앱 활성화 | 없음 |

**iTerm2/Terminal.app 사용 시:**
처음 클릭할 때 macOS가 자동화 권한을 요청합니다. `System Settings > Privacy & Security > Automation`에서 ClaudeMonitor가 해당 터미널을 제어할 수 있도록 허용하세요.

### 3. 세션 등록

**방법 A: 슬래시 커맨드 (추천)**

`~/.claude/commands/monitor.md` 생성:

```markdown
Register this Claude Code session with ClaudeMonitor overlay app.

Session name: $ARGUMENTS

Steps:
1. If the session name above is empty or blank, use the basename of the current working directory as the name
2. Run the curl command below, replacing NAME with the session name and CWD with the full current working directory path:

curl -s -X POST http://localhost:9877/register -H "Content-Type: application/json" -d '{"name":"NAME","cwd":"CWD"}'

3. Report whether registration was successful based on the JSON response
```

그 다음 Claude Code 세션에서:
```
/monitor my-session-name
```

**방법 B: Settings UI**

캐릭터 우클릭 (또는 Ctrl+클릭) → Settings → Add Session

**방법 C: curl**

```bash
curl -s -X POST http://localhost:9877/register \
  -H "Content-Type: application/json" \
  -d '{"name":"my-session","cwd":"/path/to/project"}'
```

### 4. 아바타 설정

Settings에서 GIF/PNG/JPG 파일을 선택하면 `~/.claude-monitor/avatars/`에 자동 복사됩니다.
GIF 파일은 애니메이션으로 표시됩니다.

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

`terminal` 값: `iTerm2`, `Terminal`, `tmux`, `Warp`, `Ghostty`, `Kitty`, `Alacritty`
