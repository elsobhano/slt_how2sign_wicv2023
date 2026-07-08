# Telegram job notifications for SLURM wrappers.
# Source this from any SLURM wrapper:
#
#     source slurm_jobs/notify.sh
#     notify_start
#     trap notify_timeout SIGTERM SIGINT
#
#     <your command> >> "$OUTPUT_FILE"
#     EXIT_CODE=$?
#
#     if [ $EXIT_CODE -eq 0 ]; then
#         notify_success
#     else
#         notify_failure "$OUTPUT_FILE" $EXIT_CODE
#     fi
#     exit $EXIT_CODE
#
# Credentials live in ~/.telegram_notify (gitignored), e.g.:
#     export TG_BOT_TOKEN="123:ABC..."
#     export TG_CHAT_ID="987654321"
#
# Any notify call is a no-op when credentials are missing — the training job
# never fails because Telegram is unreachable, the file is absent, or curl
# times out.

[ -f "$HOME/.telegram_notify" ] && source "$HOME/.telegram_notify"

# Wall-clock seconds when this file was sourced. notify_start resets it so the
# duration always reflects the wrapped command, not any pre-work above.
__NOTIFY_START_TS=$SECONDS

# Raw send. Silent on failure (curl --max-time 10 || true) so a Telegram
# outage cannot abort your job.
notify() {
    [ -z "$TG_BOT_TOKEN" ] && return 0
    curl -sS --max-time 10 -X POST \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "text=$1" >/dev/null || true
}

# Format seconds as Hh Mm Ss
fmt_dur() {
    local s=$1
    printf '%dh %dm %ds' $((s/3600)) $(((s%3600)/60)) $((s%60))
}

# Send the "started" ping and reset the duration timer.
# Uses standard SLURM env vars; falls back to "(unknown)" outside a SLURM job.
notify_start() {
    __NOTIFY_START_TS=$SECONDS
    local job_name=${SLURM_JOB_NAME:-$(basename "$0")}
    local job_id=${SLURM_JOB_ID:-local}
    local node=${SLURM_NODELIST:-$(hostname)}
    notify "🚀 *Started* \`${job_name}\` (job \`${job_id}\`) on \`${node}\`"
}

notify_success() {
    local job_name=${SLURM_JOB_NAME:-$(basename "$0")}
    local job_id=${SLURM_JOB_ID:-local}
    local dur=$(fmt_dur $((SECONDS - __NOTIFY_START_TS)))
    notify "✅ *Finished* \`${job_name}\` (job \`${job_id}\`) — duration: ${dur}"
}

# Usage: notify_failure [log_file] [exit_code]
# If log_file is given, the last 15 lines are quoted in the message.
notify_failure() {
    local log_file=$1
    local exit_code=${2:-?}
    local job_name=${SLURM_JOB_NAME:-$(basename "$0")}
    local job_id=${SLURM_JOB_ID:-local}
    local dur=$(fmt_dur $((SECONDS - __NOTIFY_START_TS)))

    local body="❌ *FAILED* \`${job_name}\` (job \`${job_id}\`) exit=${exit_code} after ${dur}"

    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        # Strip markdown-active chars so a stray * or ` in the log can't break
        # formatting (or hide the message). Cap to ~2k chars so we stay under
        # Telegram's 4096-char message limit.
        local tail_lines
        tail_lines=$(tail -n 15 "$log_file" 2>/dev/null | sed 's/[`*_\[\]]//g' | head -c 2000)
        body="${body}

Last lines:
\`\`\`
${tail_lines}
\`\`\`"
    fi

    notify "$body"
}

# Meant to be installed as a SIGTERM/SIGINT trap. SLURM sends SIGTERM ~30-60s
# before hard-killing a job that hits its --time limit, so this distinguishes
# "ran out of wall-clock" from a real crash.
notify_timeout() {
    local job_name=${SLURM_JOB_NAME:-$(basename "$0")}
    local job_id=${SLURM_JOB_ID:-local}
    local dur=$(fmt_dur $((SECONDS - __NOTIFY_START_TS)))
    notify "⚠️ *Time limit hit* — \`${job_name}\` (job \`${job_id}\`) killed after ${dur}"
    exit 143
}
