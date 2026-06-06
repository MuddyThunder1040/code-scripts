#!/bin/sh
set -eu

# This script simulates a small application and writes activity to a log file.

DEFAULT_LOG_FILE="/var/log/oiasis-app.log"
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"

prepare_log_file() {
  fallback_log_file="${TMPDIR:-/tmp}/oiasis-app.log"

  if touch "$LOG_FILE" 2>/dev/null; then
    return 0
  fi

  if [ "$LOG_FILE" != "$DEFAULT_LOG_FILE" ]; then
    echo "Unable to write to log file: $LOG_FILE" >&2
    return 1
  fi

  if touch "$fallback_log_file" 2>/dev/null; then
    LOG_FILE="$fallback_log_file"
    echo "Cannot write to $DEFAULT_LOG_FILE; using $LOG_FILE instead."
    return 0
  fi

  LOG_FILE="./oiasis-app.log"
  echo "Cannot write to $DEFAULT_LOG_FILE; using $LOG_FILE instead."
  touch "$LOG_FILE"
}

log_message() {
  message="$1"

  printf '%s: %s\n' "$(date)" "$message" >> "$LOG_FILE"
}

is_vowel() {
  value="$1"

  case "$value" in
    a | e | i | o | u) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  echo "===================Executing in-out.sh==================="

  prepare_log_file

  while true; do
    printf "Enter a vowel, or zz to quit: "
    read -r user_input
    user_input="$(printf '%s' "$user_input" | tr '[:upper:]' '[:lower:]')"

    if [ "$user_input" = "zz" ]; then
      break
    fi

    if is_vowel "$user_input"; then
      echo "You entered a vowel: $user_input"
      log_message "User entered a vowel: $user_input"
    else
      echo "You did not enter a vowel: $user_input"
      log_message "User did not enter a vowel: $user_input"
    fi
  done

  echo "===================Finished executing in-out.sh==================="
}

main "$@"
