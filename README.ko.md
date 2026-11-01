# Sleep Guard for Mac

[English](README.md)

덮개를 닫아도 Mac이 잠들지 않게 해서, 이동하는 동안에도 긴 빌드나 다운로드, AI 코딩 에이전트 작업이 계속 돌게 합니다. 정해진 시간이 지나면 저절로 꺼지고, 켜져 있는 동안에는 메뉴 막대에 표시가 뜹니다.

```console
$ awake 90m
잠자기 방지 켜짐: 1시간 30분 뒤 자동 해제
```

켜져 있는 동안 메뉴 막대에 `☕️ 1:29`처럼 남은 시간이 보입니다. 누르면 바로 끌 수 있습니다.

만든 배경과 과정: [잠들지 않는 맥북 만들기](https://tedfactory.com/notes/essays/keep-macbook-awake-lid-closed/) (에세이)

## `caffeinate`로는 안 되나요?

`caffeinate -i`는 입력이 없어서 저절로 잠드는 것만 막습니다. Apple의 IOKit 문서에도 이 방식으로는 덮개를 닫거나, Apple 메뉴에서 잠자기를 고르거나, 배터리가 거의 다 떨어지면 잠들 수 있다고 적혀 있습니다. `caffeinate -s`는 "전원이 연결돼 있을 때 시스템 잠자기를 막는다"고만 문서화돼 있고, 덮개를 닫을 때의 동작은 나와 있지 않습니다. 덮개를 닫는 상황에서는 기대하지 않는 게 안전합니다.

덮개를 닫아도 잠들지 않게 하려면 `sudo pmset -a disablesleep 1`이 필요합니다. 그런데 이건 시스템 설정이라 명령이 끝나도, 재부팅해도 직접 끄기 전까지 그대로 남습니다. 깜빡하면 가방 안에서도 계속 깨어 있습니다.

Sleep Guard는 `disablesleep`을 감싸서 잊어버리기 어렵게 만듭니다.

| | `caffeinate` | `pmset disablesleep` | Sleep Guard |
|---|---|---|---|
| 덮개를 닫아도 유지 | 안 됨 (`-i`) / 문서에 없음 (`-s`) | 됨 | 됨 |
| 저절로 꺼짐 | 프로세스가 끝날 때 | 안 꺼짐 | 정해진 시간 뒤 (기본 3시간) |
| 켜져 있는 게 보임 | 안 보임 | 안 보임 | 메뉴 막대에 ☕️와 남은 시간 |
| 재부팅 후 | 사라짐 | **조용히 남음** | 남지만, 로그인할 때 다시 표시 |

덮개를 열어 둘 때는 `caffeinate`, 닫아야 할 때는 Sleep Guard를 쓰세요.

## 설치

필요한 것: macOS, zsh(기본 셸), Command Line Tools(`xcode-select --install`)

```sh
git clone https://github.com/tedkim81/sleep-guard-for-mac.git
cd sleep-guard-for-mac
./install.sh
```

설치 중에 비밀번호를 한 번 묻습니다. root 전용 스크립트를 `/usr/local/libexec/sleep-guard/`에 넣기 위해서입니다.

## 사용법

```sh
awake          # 3시간 동안 잠자기 방지 + 화면 끄기
awake 90m      # 90분 (2h, 5400 같은 초 단위도 가능)
unawake        # 끄기
screenoff      # 화면만 끄기 (caffeinate와 함께 쓸 때)
```

- `awake`는 바로 끝나고, 타이머는 뒤에서 돕니다.
- `awake`를 다시 실행하면 이전 타이머를 새 타이머로 바꿉니다.
- 끌 때는 터미널에서 `unawake`를 실행하거나, 메뉴 막대에서 ☕️ → 잠자기 다시 켜기를 고릅니다.

설정은 항상 `awake`로 켜세요. `sudo pmset -a disablesleep 1`을 직접 실행하면 다음 로그인 전까지 메뉴 막대 표시가 뜨지 않습니다.

## 동작 방식

| 파일 | 설치 위치 | 역할 |
|---|---|---|
| `bin/sleepguard.sh` | `/usr/local/libexec/sleep-guard/` (root 소유) | `disablesleep` 켜기·끄기와 자동 해제 타이머 |
| `shell/awake.zsh` | `~/.local/share/sleep-guard/` (`~/.zshrc`에서 불러옴) | `awake`, `unawake`, `screenoff` |
| `app/SleepGuard.m` | `~/Applications/SleepGuard.app` | 메뉴 막대 표시 |
| LaunchAgent | `~/Library/LaunchAgents/io.github.tedkim81.sleep-guard.plist` | 로그인할 때 앱을 한 번 띄움 |

- **꺼져 있을 때는 아무것도 돌지 않습니다.** 메뉴 막대 앱은 `awake`가 띄우고, `disablesleep`이 꺼지면 스스로 종료합니다. LaunchAgent는 로그인할 때 앱을 한 번 띄울 뿐입니다. 강제 종료로 설정이 남았을 때도 이 덕분에 표시가 다시 뜹니다.
- **이전 타이머가 새 설정을 끄지 않습니다.** `/var/run/sleepguard.state`에는 현재 타이머 하나만 기록됩니다. 켜거나 끌 때는 이 기록을 먼저 지우고 이전 타이머를 종료합니다. 시간이 다 된 타이머도 자기가 현재 타이머일 때만 설정을 끕니다.

타이머 테스트는 이렇게 실행합니다. sudo 없이 가짜 `pmset`으로 돌립니다.

```sh
./test/test.sh
```

## 보안

- `awake`와 `unawake`는 `sudo`로 root 스크립트를 실행합니다. 메뉴 막대에서 끌 때도 비밀번호를 묻습니다. 비밀번호 없이 sudo를 쓰게 하는 설정은 추가하지 않습니다.
- root 스크립트는 root만 고칠 수 있는 폴더에 설치됩니다. `/usr/local`이나 `/usr/local/libexec`를 root가 아닌 사용자도 고칠 수 있으면 설치를 거부합니다.
- 메뉴 막대 앱은 내 맥에서 소스로 직접 빌드하고 임시 서명(ad-hoc)합니다. 미리 빌드한 실행 파일은 배포하지 않습니다.

## 열

닫힌 가방 안에서 깨어 있으면, 통풍구가 막히지 않아도 열이 잘 빠지지 않습니다. 가방 안 공기가 데워지고, 본체 표면으로 빠지던 열도 갇히기 때문입니다.

Apple Silicon은 과열되기 전에 성능을 낮추기 때문에, 실제 피해는 작업이 느려지고 본체가 뜨거워지고 배터리가 빨리 닳는 정도입니다. 다운로드, SSH 세션, API 응답을 기다리는 에이전트처럼 가벼운 작업은 잠깐 이동하는 정도면 대체로 괜찮습니다. 빌드, 로컬 모델 실행, 영상 인코딩처럼 무거운 작업이라면 가방에서 꺼내 들고 다니세요.

## 제거

```sh
./uninstall.sh
```

잠자기를 다시 켜고, 설치할 때 추가한 것을 모두 지웁니다.

## 테스트 환경

macOS 15.1 (Apple Silicon)

## 라이선스

[MIT](LICENSE)
