#!/bin/sh
# Tests the helper's timer logic against a fake pmset.
# Needs no sudo and never touches the real sleep setting.
cd "$(dirname "$0")/.."
T=$(mktemp -d)
trap 'pkill -f "$T/" 2>/dev/null; rm -rf "$T"' EXIT

mkdir "$T/bin"
cat > "$T/bin/pmset" <<EOF
#!/bin/sh
echo "\$*" >> "$T/log"
EOF
chmod +x "$T/bin/pmset"
sed -e "s#^PATH=#PATH=$T/bin:#" -e "s#/var/run/sleepguard.state#$T/state#" bin/sleepguard.sh > "$T/sleepguard.sh"
S="$T/sleepguard.sh"

fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }
last() { tail -1 "$T/log" 2>/dev/null; }

sh "$S" start 2
check "start disables sleep" '[ "$(last)" = "-a disablesleep 1" ]'
check "start writes the state file" '[ -f "$T/state" ]'
sleep 3
check "timer re-enables sleep when time is up" '[ "$(last)" = "-a disablesleep 0" ]'
check "timer removes the state file" '[ ! -f "$T/state" ]'

: > "$T/log"
sh "$S" start 2
old=$(cut -d' ' -f1 "$T/state")
sh "$S" start 60
sleep 3
check "restart kills the previous timer" '! kill -0 "$old" 2>/dev/null'
check "previous timer does not re-enable sleep" '! grep -q "disablesleep 0" "$T/log"'

new=$(cut -d' ' -f1 "$T/state")
sh "$S" stop
sleep 1
check "stop kills the timer" '! kill -0 "$new" 2>/dev/null'
check "stop re-enables sleep" '[ "$(last)" = "-a disablesleep 0" ]'
check "stop removes the state file" '[ ! -f "$T/state" ]'

check "rejects a non-numeric duration" '! sh "$S" start abc 2>/dev/null'
check "rejects a zero duration" '! sh "$S" start 0 2>/dev/null'
check "rejects an absurdly long duration" '! sh "$S" start 999999999 2>/dev/null'
check "rejected durations leave sleep alone" '[ ! -f "$T/state" ]'

sleep 60 &
other=$!
echo "$other 0" > "$T/state"
sh "$S" stop
check "stop never kills an unrelated process with a stale pid" 'kill -0 "$other" 2>/dev/null'
kill "$other"
wait "$other" 2>/dev/null

exit $fail
