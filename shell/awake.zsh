# Sleep Guard: keep the Mac awake even with the lid closed (pmset disablesleep)
#   awake [time]  turn on and switch the display off. time: 90m, 2h or seconds (default 3h)
#   unawake       turn off
#   screenoff     switch the display off only (e.g. together with caffeinate)

SLEEPGUARD_HELPER=/usr/local/libexec/sleep-guard/sleepguard.sh
SLEEPGUARD_APP="$HOME/Applications/SleepGuard.app"

_sleepguard_ko() { [[ ${LC_ALL:-${LC_MESSAGES:-$LANG}} == ko* ]] }

awake() {
  local t=${1:-3h} secs=0
  case $t in
    <->h) secs=$(( ${t%h} * 3600 )) ;;
    <->m) secs=$(( ${t%m} * 60 )) ;;
    <->)  secs=$t ;;
  esac
  if (( secs <= 0 )); then
    _sleepguard_ko && echo "사용법: awake [90m|2h|초]" >&2 || echo "usage: awake [90m|2h|seconds]" >&2
    return 1
  fi
  sudo "$SLEEPGUARD_HELPER" start "$secs" || return
  open -g -a "$SLEEPGUARD_APP"
  if _sleepguard_ko; then
    echo "잠자기 방지 켜짐: $(( secs / 3600 ))시간 $(( secs % 3600 / 60 ))분 뒤 자동 해제"
  else
    echo "Sleep disabled: turns off automatically in $(( secs / 3600 ))h $(( secs % 3600 / 60 ))m"
  fi
  pmset displaysleepnow
}

unawake() {
  sudo "$SLEEPGUARD_HELPER" stop || return
  _sleepguard_ko && echo "잠자기 방지 꺼짐" || echo "Sleep enabled again"
}

screenoff() {
  pmset displaysleepnow
}
