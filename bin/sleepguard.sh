#!/bin/sh
# Sleep Guard helper (runs as root)
#   sleepguard.sh start [seconds]  turn on disablesleep and start the auto-off timer (replaces any running timer)
#   sleepguard.sh stop             stop the timer and turn disablesleep off
#
# State file: one line "<timer pid> <deadline epoch>". /var/run is cleared on reboot.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
STATE=/var/run/sleepguard.state

# Remove the state file first, then kill the timer.
# A killed timer never touches pmset, so an old timer can't turn off a setting made by a newer start.
stop_timer() {
  [ -f "$STATE" ] || return 0
  pid=$(cut -d' ' -f1 "$STATE")
  rm -f "$STATE"
  case "$(ps -p "$pid" -o command= 2>/dev/null)" in
    *sleepguard.sh*_timer*) kill "$pid" 2>/dev/null ;;
  esac
}

case "$1" in
  start)
    secs=${2:-10800}
    case "$secs" in ''|*[!0-9]*|?????????*) secs=0 ;; esac
    if [ "$secs" -le 0 ]; then echo "seconds must be a positive number below 100000000: $2" >&2; exit 1; fi
    stop_timer
    pmset -a disablesleep 1 || exit 1
    nohup /bin/sh "$0" _timer "$secs" >/dev/null 2>&1 &
    echo "$! $(( $(date +%s) + secs ))" > "$STATE"
    chmod 644 "$STATE"
    ;;
  stop)
    stop_timer
    pmset -a disablesleep 0
    ;;
  _timer)
    trap 'kill $sp 2>/dev/null; exit 0' TERM
    sleep "$2" & sp=$!
    wait $sp
    # Time is up: turn off only if this is still the current timer.
    # (A `start` landing between this check and pmset below can still be undone; the window is a few ms.)
    if [ "$(cut -d' ' -f1 "$STATE" 2>/dev/null)" = "$$" ]; then
      rm -f "$STATE"
      pmset -a disablesleep 0
    fi
    ;;
  *)
    echo "usage: $0 start [seconds] | stop" >&2
    exit 1
    ;;
esac
