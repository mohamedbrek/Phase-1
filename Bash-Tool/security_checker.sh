#!/usr/bin/env bash

set -u
export LC_ALL=C.UTF-8 2>/dev/null || true

VERSION="1.0"
PASS=0; WARN=0; FAIL=0; INFO=0
QUIET=0; PLAIN=0; REPORT=""

usage() { sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; }

while getopts "qno:h" opt; do
  case $opt in
    q) QUIET=1 ;;
    n) PLAIN=1 ;;
    o) REPORT=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

term_width() {
  local w=${COLUMNS:-}
  [[ -z $w ]] && w=$(tput cols 2>/dev/null)
  [[ $w =~ ^[0-9]+$ ]] || w=80
  (( w > 100 )) && w=100
  (( w < 40 )) && w=40
  echo "$w"
}

IS_TTY=0; [[ -t 1 ]] && IS_TTY=1
[[ -n ${NO_COLOR:-} || $IS_TTY -eq 0 ]] && PLAIN=1

if (( PLAIN )); then
  C_G=""; C_Y=""; C_R=""; C_C=""; C_B=""; C_D=""; C_N=""
  RULE="-"; ELL="..."; BAR_ON="#"; BAR_OFF="-"
else
  C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_C=$'\e[36m'
  C_B=$'\e[1m'; C_D=$'\e[2m'; C_N=$'\e[0m'
  RULE="─"; ELL="…"; BAR_ON="█"; BAR_OFF="░"
fi

repeat() { local s="" i; for ((i = 0; i < $2; i++)); do s+=$1; done; printf '%s' "$s"; }

fit() {
  local text=$1 max=$2
  if (( ${#text} > max )); then
    printf '%s%s' "${text:0:max-${#ELL}}" "$ELL"
  else
    printf '%s' "$text"
  fi
}

status() {
  (( IS_TTY && ! PLAIN )) || return 0
  printf '\r\e[2K%s%s%s' "$C_D" "$(fit "  scanning: $1" "$(term_width)")" "$C_N"
}

clear_status() { (( IS_TTY && ! PLAIN )) && printf '\r\e[2K'; return 0; }

section() {
  clear_status
  local w; w=$(term_width)
  local title=" $1 "
  printf '\n%s%s%s%s%s\n' "$C_B$C_C" "$title" "$C_D" "$(repeat "$RULE" $((w - ${#title})))" "$C_N"
}

emit() {
  local level=$1 title=$2 detail=${3:-} badge color
  case $level in
    PASS) ((PASS++)); badge=" OK "; color=$C_G ;;
    WARN) ((WARN++)); badge="WARN"; color=$C_Y ;;
    FAIL) ((FAIL++)); badge="FAIL"; color=$C_R ;;
    INFO) ((INFO++)); badge="INFO"; color=$C_C ;;
  esac
  (( QUIET )) && [[ $level == PASS || $level == INFO ]] && return 0

  clear_status
  local w; w=$(term_width)
  local avail=$(( w - 9 ))
  local main; main=$(fit "$title" "$avail")
  printf '  %s[%s]%s %s\n' "$color" "$badge" "$C_N" "$main"

  if [[ -n $detail ]]; then
    printf '         %s%s%s\n' "$C_D" "$(fit "$detail" "$avail")" "$C_N"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

check_system() {
  section "System"
  status "system info"
  local os="unknown"
  [[ -r /etc/os-release ]] && os=$(. /etc/os-release; echo "${PRETTY_NAME:-unknown}")
  emit INFO "Host: $(hostname)" "$os, kernel $(uname -r), up $(uptime -p 2>/dev/null | sed 's/^up //')"
  if (( EUID == 0 )); then
    emit PASS "Running as root"
  else
    emit WARN "Not running as root" "some checks will be skipped; use sudo"
  fi
}

check_accounts() {
  section "Accounts"
  status "accounts"

  local uid0; uid0=$(awk -F: '$3==0 && $1!="root"{printf "%s ", $1}' /etc/passwd)
  if [[ -n $uid0 ]]; then emit FAIL "Extra accounts with UID 0" "$uid0"
  else emit PASS "Only root has UID 0"; fi

  if [[ -r /etc/shadow ]]; then
    local empty; empty=$(awk -F: '$2==""{printf "%s ", $1}' /etc/shadow)
    if [[ -n $empty ]]; then emit FAIL "Accounts with empty passwords" "$empty"
    else emit PASS "No empty passwords"; fi
  else
    emit WARN "Cannot read /etc/shadow" "run as root to check password hashes"
  fi

  if grep -rqsE '^[^#].*NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null; then
    emit WARN "sudo NOPASSWD rules present" "review /etc/sudoers and /etc/sudoers.d"
  else
    emit PASS "No NOPASSWD sudo rules"
  fi

  local maxdays; maxdays=$(awk '/^PASS_MAX_DAYS/{print $2}' /etc/login.defs 2>/dev/null)
  if [[ $maxdays =~ ^[0-9]+$ ]] && (( maxdays <= 365 )); then
    emit PASS "Password max age is $maxdays days"
  else
    emit WARN "Password expiry not enforced" "PASS_MAX_DAYS in /etc/login.defs"
  fi
}

check_permissions() {
  section "File permissions"
  status "file permissions"
  local -A want=( [/etc/passwd]=644 [/etc/group]=644 [/etc/shadow]=640 [/etc/gshadow]=640 [/etc/sudoers]=440 )
  local f actual
  for f in /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/sudoers; do
    [[ -e $f ]] || continue
    actual=$(stat -c '%a' "$f")
    if (( 8#$actual <= 8#${want[$f]} )); then
      emit PASS "$f ($actual)"
    else
      emit FAIL "$f is $actual" "should be ${want[$f]} or stricter"
    fi
  done
}

sshd_value() {
  local cfg=/etc/ssh/sshd_config
  if (( EUID == 0 )) && have sshd; then
    sshd -T 2>/dev/null | awk -v k="$(tr 'A-Z' 'a-z' <<<"$1")" '$1==k{print tolower($2); exit}'
  else
    grep -hiE "^\s*$1\s" "$cfg" /etc/ssh/sshd_config.d/*.conf 2>/dev/null | head -n1 | awk '{print tolower($2)}'
  fi
}

check_ssh() {
  section "SSH"
  status "ssh"
  if [[ ! -r /etc/ssh/sshd_config ]]; then
    emit INFO "SSH server not installed or not readable"
    return
  fi
  local v
  v=$(sshd_value PermitRootLogin)
  if [[ $v == no || $v == prohibit-password || $v == without-password ]]; then
    emit PASS "Root login restricted ($v)"
  else
    emit FAIL "Root SSH login allowed" "set PermitRootLogin no (now: ${v:-default})"
  fi

  v=$(sshd_value PasswordAuthentication)
  if [[ $v == no ]]; then emit PASS "Password login disabled (keys only)"
  else emit WARN "SSH password login enabled" "prefer key-based authentication"; fi

  v=$(sshd_value PermitEmptyPasswords)
  if [[ $v == yes ]]; then emit FAIL "Empty SSH passwords permitted"
  else emit PASS "Empty SSH passwords refused"; fi
}

check_network() {
  section "Network"
  status "network"
  if have ss; then
    local exposed
    exposed=$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -E '^(0\.0\.0\.0|\*|\[::\]):' | sed 's/.*://' | sort -un | tr '\n' ' ')
    if [[ -z $exposed ]]; then
      emit PASS "No services exposed on all interfaces"
    else
      emit WARN "Ports open on all interfaces" "$exposed"
    fi
  else
    emit INFO "'ss' not found, skipping port scan"
  fi

  if have ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    emit PASS "Firewall active (ufw)"
  elif have firewall-cmd && firewall-cmd --state 2>/dev/null | grep -q running; then
    emit PASS "Firewall active (firewalld)"
  elif have nft && [[ $(nft list ruleset 2>/dev/null | wc -l) -gt 5 ]]; then
    emit PASS "Firewall rules present (nftables)"
  elif have iptables && [[ $(iptables -S 2>/dev/null | wc -l) -gt 3 ]]; then
    emit PASS "Firewall rules present (iptables)"
  else
    emit FAIL "No active firewall detected" "enable ufw or firewalld"
  fi
}

sysctl_is() {
  local val; val=$(sysctl -n "$1" 2>/dev/null) || { return 0; }
  if [[ $val == "$2" ]]; then emit PASS "$3"
  else emit WARN "Not hardened: $3" "$1 = $val (want $2)"; fi
}

check_kernel() {
  section "Kernel hardening"
  status "kernel settings"
  have sysctl || { emit INFO "sysctl not available"; return; }
  sysctl_is kernel.randomize_va_space 2 "ASLR fully enabled"
  sysctl_is net.ipv4.tcp_syncookies 1 "SYN cookies enabled"
  sysctl_is net.ipv4.conf.all.accept_redirects 0 "ICMP redirects ignored"
  sysctl_is net.ipv4.conf.all.rp_filter 1 "Reverse-path filtering on"
  sysctl_is kernel.dmesg_restrict 1 "dmesg restricted to root"
}

check_filesystem() {
  section "Filesystem"
  status "world-writable files (may take a moment)"
  local ww
  ww=$(timeout 20 find / -xdev -type f -perm -0002 -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -n 5)
  if [[ -n $ww ]]; then
    emit WARN "World-writable files found" "$(echo "$ww" | head -n 3 | tr '\n' ' ')"
  else
    emit PASS "No world-writable files"
  fi

  status "SUID binaries"
  local n; n=$(timeout 20 find / -xdev -type f -perm -4000 2>/dev/null | wc -l)
  emit INFO "$n SUID binaries" "review: find / -xdev -perm -4000"
}

check_updates() {
  section "Patching"
  status "package updates"
  local n
  if have apt; then
    n=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    if (( n > 0 )); then emit WARN "$n packages need updating" "sudo apt update && sudo apt upgrade"
    else emit PASS "System is up to date"; fi
  elif have dnf; then
    if dnf check-update -q >/dev/null 2>&1; then emit PASS "System is up to date"
    else emit WARN "Updates available" "sudo dnf upgrade"; fi
  else
    emit INFO "Unknown package manager, skipped"
  fi
}

check_services() {
  section "Logging & protection"
  status "services"
  have systemctl || { emit INFO "systemd not available"; return; }
  local svc
  for svc in auditd fail2ban; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then emit PASS "$svc running"
    else emit WARN "$svc not running"; fi
  done
  if systemctl is-active --quiet rsyslog 2>/dev/null || systemctl is-active --quiet systemd-journald 2>/dev/null; then
    emit PASS "System logging active"
  else
    emit FAIL "No system logging service running"
  fi
}

check_hardening() {
  section "Extra hardening"
  status "extra hardening"

  local mode; mode=$(stat -c '%a' /tmp 2>/dev/null)
  if [[ $mode == 1* ]]; then emit PASS "/tmp has sticky bit ($mode)"
  else emit FAIL "/tmp missing sticky bit" "fix: chmod +t /tmp"; fi

  local cw; cw=$(find /etc/cron* -type f -perm -0002 2>/dev/null | head -n 3 | tr '\n' ' ')
  if [[ -n $cw ]]; then emit FAIL "World-writable cron files" "$cw"
  else emit PASS "Cron files not world-writable"; fi

  if [[ -d /home ]]; then
    local homes; homes=$(find /home -mindepth 1 -maxdepth 1 -type d -perm -0005 2>/dev/null | wc -l)
    if (( homes > 0 )); then emit WARN "$homes home dirs open to other users" "fix: chmod 750 /home/USER"
    else emit PASS "Home directories are private"; fi
  fi

  if have dpkg && dpkg -s unattended-upgrades >/dev/null 2>&1; then
    emit PASS "Automatic security updates installed"
  elif have rpm && rpm -q dnf-automatic >/dev/null 2>&1; then
    emit PASS "Automatic security updates installed"
  else
    emit WARN "Automatic security updates not set up" "apt: unattended-upgrades | dnf: dnf-automatic"
  fi

  if [[ -r /etc/ssh/sshd_config ]]; then
    local tries; tries=$(sshd_value MaxAuthTries)
    if [[ $tries =~ ^[0-9]+$ ]] && (( tries <= 4 )); then emit PASS "SSH MaxAuthTries is $tries"
    else emit WARN "SSH MaxAuthTries is ${tries:-default (6)}" "set MaxAuthTries 4 or lower"; fi
  fi
}

summary() {
  clear_status
  local w total score barw filled
  w=$(term_width)
  total=$((PASS + WARN + FAIL))
  score=0; (( total > 0 )) && score=$(( PASS * 100 / total ))

  section "Summary"
  printf '  %sOK %d%s   %sWARN %d%s   %sFAIL %d%s\n' \
    "$C_G" "$PASS" "$C_N" "$C_Y" "$WARN" "$C_N" "$C_R" "$FAIL" "$C_N"

  barw=$(( w - 16 )); (( barw > 40 )) && barw=40; (( barw < 10 )) && barw=10
  filled=$(( score * barw / 100 ))
  local color=$C_G
  (( score < 80 )) && color=$C_Y
  (( score < 50 )) && color=$C_R
  printf '  Score %s%s%s%s %d%%\n' "$color" "$(repeat "$BAR_ON" "$filled")" \
    "$C_D$(repeat "$BAR_OFF" $((barw - filled)))" "$C_N" "$score"
  echo
}

main() {
  printf '%ssecurity_checker v%s%s  %s%s%s\n' "$C_B" "$VERSION" "$C_N" "$C_D" "$(date '+%F %H:%M')" "$C_N"
  check_system
  check_accounts
  check_permissions
  check_ssh
  check_network
  check_kernel
  check_filesystem
  check_updates
  check_services
  check_hardening
  summary
}

trap 'clear_status; exit 130' INT

if [[ -n $REPORT ]]; then
  main | tee >(sed 's/\x1b\[[0-9;]*[A-Za-z]//g' > "$REPORT")
  echo "Report saved to $REPORT"
else
  main
fi

(( FAIL > 0 )) && exit 2
exit 0