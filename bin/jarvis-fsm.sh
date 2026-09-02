#!/usr/bin/env bash
# jarvis-fsm.sh — the transition table, the identity, and the handles.
#
# Sourced by bin/jarvis; a library, not a verb. It is kept apart for two
# reasons. The first is that a state machine
# scattered across fifteen `set_state` calls is not a state machine, it is a
# habit — one file that names every legal move is something you can read in
# a year and argue with. The second is that the tests can drive this alone:
# source it, claim, transition, and watch what it refuses.
#
#
# ## The states
#
# Eight, and the one-word name of the current one lives in $RUN_DIR/state.
# That file is a PUBLIC CONTRACT — bin/jarvis-wake.py reads it, and so does
# the out-of-repo macarchy-dfr Touch Bar daemon — so it stays exactly one
# lowercase word and nothing else, forever.
#
#     idle          at rest, and the only state anything autonomous may
#                   start from
#     listening     the microphone is open, a recorder is running
#     transcribing  the recording is being turned into words
#     thinking      the brain has the question
#     speaking      the voice has the floor
#     followup      the reply is out and the wake daemon is listening for a
#                   rejoinder, no wake word needed
#     sleeping      a dream is consolidating memory
#     cancelling    an abort is under way: five process groups are being
#                   killed, and that takes long enough to be a state of its
#                   own rather than a gap between two writes
#
#
# ## The moves
#
# Nine events, and only the couples below are legal. `transition <event>`
# refuses everything else — loudly, in the log, and without touching the
# record. That refusal is the point: `thinking:finish` and `listening:speak`
# are not states of the world, they are bugs arriving.
#
#     listen   open the ear. From rest (idle, followup, sleeping) it starts
#              an exchange; from `speaking` it is a barge-in — the user
#              talking over the answer.
#     finish   close the ear and start transcribing. Only from `listening`.
#     ask      hand the words to the brain. From `transcribing` after a
#              recording, and from anywhere at all for a typed or piped
#              question: `jarvis ask` claims the machine and stops every
#              group before it asks, so a question typed into the prompt bar
#              while he is still answering the last one wins, as it should.
#     speak    take the floor. From `thinking` in the ordinary case, from
#              `transcribing` for « Je n'ai rien entendu. », from `sleeping`
#              for a dream's one sentence, from `speaking` for the next
#              sentence of the same reply. Never from `listening`: speaking
#              into an open microphone is how his own voice ended up in the
#              transcript as the user's question.
#     done     the reply ended and earned a follow-up window. Only from
#              `speaking`, and only when the wake daemon is alive to watch
#              it (after_speaking decides that, not the table).
#     settle   the follow-up window closed unused. Only from `followup`.
#     sleep    start dreaming. Only from `idle`: a dream never takes a body
#              that is in the middle of something.
#     rest     come home. From anywhere, and the one every stage owes on
#              its way out (see finish_stage below).
#     cancel   stop, from anywhere, whatever was happening. It lands in
#              `cancelling` and not in `idle`, because between the decision
#              to abort and the last process group actually dying there is a
#              moment where the machine is neither working nor at rest — and
#              a press arriving inside that moment must find a door that is
#              closed, not open the microphone on top of a recorder that is
#              still on its way out. `rest` is what opens it again, and the
#              watchdog's shortest deadline watches over it.
#
# The full 8 × 9 grid is printed by `JARVIS_FSM_DRYRUN=1 bin/jarvis-fsm.sh`,
# and tests/fixtures/transitions.txt is that grid frozen: the suite diffs
# them, so the table cannot drift from its documentation without a red line.
#
#
# ## The identity
#
# The one-word mirror says WHAT the machine is doing and never WHICH ATTEMPT
# is doing it, and that single hole is ten of the confirmed bugs. So beside
# it lives $RUN_DIR/state.rec, one line, written atomically:
#
#     state=speaking since=1788268389886 owner=41207 epoch=12 ask=1788268389-12
#
#     state   the same word as the mirror, so the record is self-contained
#     since   epoch milliseconds of this transition — how long he has been
#             here, which is what the dead time on `press` reads
#     owner   the process group of the invocation that holds the machine.
#             It identifies; it is not a kill target — an invocation
#             launched from a shell shares that shell's group. What a
#             watchdog kills is the named groups below, which are its own.
#     epoch   a counter, bumped by every `claim`
#     ask     an id for the exchange in flight, empty at rest
#
# `claim` bumps the epoch and remembers it in MY_EPOCH; `mine` says whether
# that is still the epoch on disk. A stage captures its epoch at entry and
# guards every side effect with `mine || return 0`, so an invocation that
# was displaced — cancelled, barged in on, replaced by a second press —
# stops writing to the world instead of finishing a job nobody wants any
# more. `transition` enforces the same rule itself, which is what makes an
# unguarded site fail safe rather than fail loud.
#
# An invocation that never claimed (settle, a status read) owns nothing: it
# is judged by the table alone, and `mine` is false for it — so it can never
# write `idle` over a state it did not itself set.
#
#
# ## The handles
#
# No long stage had a pid on disk, which is why cancelling has never once
# cancelled anything. Every external stage now runs under `group_run <name>`
# in a session of its own, with its process group id in $RUN_DIR/pids/<name>
# — record, stt, brain, voice, play. The GROUP is the point: `claude` runs
# its own Bash tool subprocesses, and a signal sent to a bare pid never
# reaches them.

# Sourced from bin/jarvis, which has already resolved these; runnable alone,
# where JARVIS_RUN/JARVIS_STATE do the same job they do for the FSM.
RUN_DIR="${RUN_DIR:-${JARVIS_RUN:-${XDG_RUNTIME_DIR:-/tmp}/jarvis}}"
STATE_DIR="${STATE_DIR:-${JARVIS_STATE:-$HOME/.local/state/jarvis}}"
LOG="${LOG:-$STATE_DIR/jarvis.log}"
STATE_FILE="${STATE_FILE:-$RUN_DIR/state}"
STATE_REC="$RUN_DIR/state.rec"
FSM_LOCK="$RUN_DIR/fsm.lock"
PIDS_DIR="$RUN_DIR/pids"
# Self-sufficient on purpose: a test that drives the table alone should not
# have to know that bin/jarvis makes these first.
mkdir -p "$RUN_DIR" "$STATE_DIR"

# bin/jarvis has its own log(); standing alone we still want the line.
fsm_log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >>"$LOG"; }

# ------------------------------------------------------------- the table

# The couples, and nothing else. Prints the destination state, or nothing
# at all when the move is not one the machine makes.
fsm_next() {
	case "$1:$2" in
	idle:listen | followup:listen | sleeping:listen | speaking:listen | listening:listen) echo listening ;;
	listening:finish) echo transcribing ;;
	idle:ask | listening:ask | transcribing:ask | thinking:ask | speaking:ask | followup:ask | sleeping:ask) echo thinking ;;
	idle:speak | followup:speak | sleeping:speak | transcribing:speak | thinking:speak | speaking:speak) echo speaking ;;
	speaking:done) echo followup ;;
	followup:settle) echo idle ;;
	idle:sleep) echo sleeping ;;
	idle:rest | listening:rest | transcribing:rest | thinking:rest | speaking:rest | followup:rest | sleeping:rest | cancelling:rest) echo idle ;;
	idle:cancel | listening:cancel | transcribing:cancel | thinking:cancel | speaking:cancel | followup:cancel | sleeping:cancel | cancelling:cancel) echo cancelling ;;
	esac
}

FSM_STATES=(idle listening transcribing thinking speaking followup sleeping cancelling)
# `done` is quoted because it is a loop keyword: bare, a linter reads the
# array as an unterminated `for`. It is an event name here, nothing more.
FSM_EVENTS=(listen finish ask speak "done" settle sleep rest cancel)

# The whole grid, one row per state. This is the documentation of record:
# tests/fixtures/transitions.txt holds a copy and the suite diffs the two.
fsm_table() {
	local from event to
	{
		printf '%-13s' ""
		for event in "${FSM_EVENTS[@]}"; do printf '%-14s' "$event"; done
		printf '\n'
		for from in "${FSM_STATES[@]}"; do
			printf '%-13s' "$from"
			for event in "${FSM_EVENTS[@]}"; do
				to=$(fsm_next "$from" "$event")
				printf '%-14s' "${to:--}"
			done
			printf '\n'
		done
	} | sed 's/ *$//'
}

# ------------------------------------------------------------ the record

state() { cat "$STATE_FILE" 2>/dev/null || echo idle; }

# The record into REC_*. A missing or damaged record falls back to the
# one-word mirror — which is what a first run, and an upgrade landing
# mid-conversation, both look like — and to idle when even that is absent.
rec_read() {
	local line
	REC_STATE="" REC_SINCE=0 REC_OWNER=0 REC_EPOCH=0 REC_ASK=""
	line=$(cat "$STATE_REC" 2>/dev/null)
	[[ $line =~ state=([a-z]+) ]] && REC_STATE=${BASH_REMATCH[1]}
	[[ $line =~ since=([0-9]+) ]] && REC_SINCE=${BASH_REMATCH[1]}
	[[ $line =~ owner=([0-9]+) ]] && REC_OWNER=${BASH_REMATCH[1]}
	[[ $line =~ epoch=([0-9]+) ]] && REC_EPOCH=${BASH_REMATCH[1]}
	[[ $line =~ ask=([^[:space:]]+) ]] && REC_ASK=${BASH_REMATCH[1]}
	[[ -n $REC_STATE ]] || REC_STATE=$(cat "$STATE_FILE" 2>/dev/null)
	[[ -n $REC_STATE ]] || REC_STATE=idle
	return 0
}

# Record and mirror, both by rename so no reader ever sees half a word.
# Called with the lock held, and only from fsm_move.
rec_write() {
	local to="$1" tmp
	REC_STATE="$to"
	REC_SINCE=$(date +%s%3N)
	tmp="$STATE_REC.$$"
	printf 'state=%s since=%s owner=%s epoch=%s ask=%s\n' \
		"$REC_STATE" "$REC_SINCE" "$REC_OWNER" "$REC_EPOCH" "$REC_ASK" >"$tmp" &&
		mv -f "$tmp" "$STATE_REC"
	tmp="$STATE_FILE.$$"
	printf '%s' "$to" >"$tmp" && mv -f "$tmp" "$STATE_FILE"
}

# Our own process group, for the record's `owner` — who is holding the
# machine, so a watchdog can say so. /proc/self/stat rather than ps: comm is
# parenthesized and may contain spaces, so the fields are counted after the
# closing parenthesis (state, ppid, pgrp).
fsm_pgid() {
	local stat
	read -r stat </proc/self/stat 2>/dev/null || { echo "$$"; return; }
	stat=${stat#*') '}
	# shellcheck disable=SC2086
	set -- $stat
	echo "${3:-$$}"
}

# ---------------------------------------------------- claiming and owning

# Take the machine without moving it — for a stage that is about to speak or
# think from wherever it already is. Everything after this point in the
# calling invocation is guarded by `mine`, and every other invocation's guard
# now fails.
claim() { fsm_move "" claim; }

# Take the machine AND make the move, in one gesture under one lock. A press
# is one gesture, and splitting it in two is a wedge: two presses a
# millisecond apart both claimed, one found its move refused a moment later,
# and left the other one deaf and the machine stopped mid-stage. Deciding the
# move is legal is therefore part of becoming the owner — refuse the move,
# and the epoch never moves at all.
claim_transition() { fsm_move "$1" claim; }

# Take the machine AND make the move, but only if it is still the machine you
# looked at. The watchdog decides on a reading taken a moment earlier — it
# reads a wedged `thinking`, then kills five process groups — and in between
# the stage may have come back by itself or a press may have started
# something new. Bumping the epoch then would abort the WRONG exchange, and
# no amount of care outside the lock can close that window: the comparison
# has to happen under it, beside the write it guards.
claim_if() {
	local expect="$1" event="$2" rc
	FSM_EXPECT="$expect"
	fsm_move "$event" claim
	rc=$?
	FSM_EXPECT=""
	return "$rc"
}

# Still ours? False for an invocation that never claimed: it owns nothing,
# and a side effect it is unsure of is one it should not fire.
mine() {
	[[ -n ${MY_EPOCH:-} ]] || return 1
	rec_read
	[[ $REC_EPOCH == "$MY_EPOCH" ]]
}

# True when the machine has been where it is for at least N milliseconds.
# The dead time behind `press`: the button and the wake daemon's silence
# timer firing together used to transcribe one utterance twice and ask the
# brain the same question twice.
held_for() {
	local ms="$1" now
	rec_read
	now=$(date +%s%3N)
	((now - REC_SINCE >= ms))
}

# The same age, as a number — asked BEFORE a claim, since claiming moves
# `since` to now. An unknown age (no record yet: a first run, or an upgrade
# landing mid-conversation) is reported as zero rather than as the whole of
# the epoch, so nothing downstream files a fifty-year abort.
held_ms() {
	local now
	rec_read
	((REC_SINCE > 0)) || { echo 0; return 0; }
	now=$(date +%s%3N)
	echo $((now - REC_SINCE))
}

# One move, by an invocation that already owns the machine. Returns 1
# without writing when the move is not in the table, or when this invocation
# has been displaced since it claimed.
transition() { fsm_move "$1" keep; }

# The whole of both. The lock covers the read, the decision and the write and
# NOTHING else — a lock held across a long stage is a wedge waiting to happen
# — and the body's side of the transition (the fish, the Touch Bar, the
# parked bubbles) runs afterwards, through the on_state_change hook that
# bin/jarvis defines.
fsm_move() {
	local event="$1" mode="$2" from to
	exec 8>"$FSM_LOCK"
	flock -x 8
	rec_read
	from=$REC_STATE
	to=$from
	if [[ -n ${FSM_EXPECT:-} && $FSM_EXPECT != "$REC_EPOCH" ]]; then
		flock -u 8
		exec 8>&-
		fsm_log "fsm: $from:$event stood down — epoch was $FSM_EXPECT, is now $REC_EPOCH"
		return 1
	fi
	if [[ -n $event ]]; then
		to=$(fsm_next "$from" "$event")
		if [[ -z $to ]]; then
			flock -u 8
			exec 8>&-
			fsm_log "fsm: refused $from:$event"
			return 1
		fi
	fi
	if [[ $mode == claim ]]; then
		MY_EPOCH=$((REC_EPOCH + 1))
		REC_EPOCH=$MY_EPOCH
		REC_OWNER=$(fsm_pgid)
		REC_ASK="$(date +%s)-$MY_EPOCH"
		fsm_log "claim: epoch=$MY_EPOCH owner=$REC_OWNER state=$from"
	elif [[ -n ${MY_EPOCH:-} && $MY_EPOCH != "$REC_EPOCH" ]]; then
		flock -u 8
		exec 8>&-
		fsm_log "fsm: $from:$event dropped — epoch $MY_EPOCH superseded by $REC_EPOCH"
		return 1
	fi
	# Coming to rest is letting go: nobody owns an idle machine and no
	# exchange is in flight. It is the MOVE that releases, though, not the
	# destination — `claim` takes an idle machine without moving it (that is
	# `say`, which synthesizes before it takes the floor), and zeroing the
	# owner there threw away the identity of the very invocation that had
	# just asked for it. What followed inherited owner=0, so the watchdog
	# could no longer tell a dead speaker from a slow one and had to wait out
	# the full five minutes instead of freeing it on the next pulse.
	if [[ -n $event && $to == idle ]]; then
		REC_OWNER=0
		REC_ASK=""
	fi
	rec_write "$to"
	flock -u 8
	exec 8>&-
	[[ -n $event ]] || return 0
	fsm_log "state: $to"
	declare -F on_state_change >/dev/null && on_state_change "$to"
	return 0
}

# The stages that run INSIDE an invocation — transcribing, thinking,
# speaking, sleeping, cancelling — must not survive it. A synthesis that
# refuses, a brain that dies, a kill in the middle: whatever the exit path,
# the fish comes home instead of freezing mid-sentence with the wake word
# dead and every automatism behind it. `listening` and `followup` are
# deliberately absent — those two are handed on to the next press and to the
# wake daemon.
stage_guard() { trap finish_stage EXIT; }

finish_stage() {
	local rc=$?
	trap - EXIT
	if mine; then
		case "$(state)" in
		transcribing | thinking | speaking | sleeping | cancelling) transition rest ;;
		esac
	fi
	exit "$rc"
}

# ----------------------------------------------------------- the handles

# Run one external stage in a session of its own and leave its process group
# id on disk under `name`. setsid makes the little shell a session leader,
# so its own pid IS the group id: it records that, runs the command, and
# takes the file back with it. setsid's « child N did not exit normally »
# — which is what a killed group looks like from here — goes to the log.
group_run() {
	local name="$1"
	shift
	mkdir -p "$PIDS_DIR"
	: >"$PIDS_DIR/$name"
	setsid --wait bash -c '
		printf %s "$$" >"$1"
		f=$1
		shift
		"$@"
		rc=$?
		[[ $(cat "$f" 2>/dev/null) == "$$" ]] && rm -f "$f"
		exit $rc
	' _ "$PIDS_DIR/$name" "$@" 2>>"$LOG"
}

# A group that is started IN THE BACKGROUND has to reserve its handle in the
# foreground first, and the ear is the only one that is — a recorder outlives
# the press that opened it on purpose. Between the `&` and group_run's own
# first line there is a fork's worth of a window, and an abort arriving inside
# it finds no file at all under `record`: kill_group has nothing to signal and
# says so by returning, the recorder starts a millisecond later, and the
# microphone stays open for the rest of the session with nothing on disk to
# reach it by. That is the exact hole this file exists to close, so it does
# not get to reopen on the one stage that needs it most. Reserving is one
# empty file; kill_group below already knows how to wait for an id to appear
# in one.
group_reserve() {
	mkdir -p "$PIDS_DIR"
	: >"$PIDS_DIR/$1"
}

# And giving it back, for the reservation that never became a group.
group_release() { rm -f "$PIDS_DIR/$1"; }

group_pgid() { cat "$PIDS_DIR/$1" 2>/dev/null; }

# Signal a whole group and forget it. TERM for anything that just has to
# stop; INT for the recorder, which finalizes its WAV header on the way out.
kill_group() {
	local name="$1" sig="${2:-TERM}" pgid="" i
	[[ -e $PIDS_DIR/$name ]] || return 0
	# The group writes its own id from inside the new session, so there is a
	# fork's worth of a window where the file exists and is still empty —
	# and, for a reserved group, one more where it has not even forked yet.
	for ((i = 0; i < 20; i++)); do
		pgid=$(group_pgid "$name")
		[[ -n $pgid ]] && break
		sleep 0.01
	done
	rm -f "$PIDS_DIR/$name"
	# Two hundred milliseconds and no id: either the group died between the
	# reservation and its first line, or it is slower to start than anything
	# measured here. Either way something may be running that nothing can now
	# reach, and a silent return is how that goes unnoticed.
	[[ -n $pgid ]] || {
		fsm_log "kill_group: $name reserved but never named itself — nothing signalled"
		return 0
	}
	kill -"$sig" "-$pgid" 2>/dev/null
	return 0
}

# Wait — briefly — for a group to actually be gone. do_finish needs it: a
# recorder that has not yet flushed its WAV header leaves a file the ear
# cannot read.
group_gone() {
	local pgid="${1:-}" i
	[[ -n $pgid ]] || return 0
	for ((i = 0; i < 20; i++)); do
		kill -0 "-$pgid" 2>/dev/null || return 0
		sleep 0.05
	done
	return 1
}

# The dry run: print the grid and stop, whether this file was executed or
# sourced (the `exit` reaches bin/jarvis, which sources it before doing
# anything). That is the whole point — the table, and no machine.
if [[ ${JARVIS_FSM_DRYRUN:-} == 1 ]]; then
	fsm_table
	exit 0
fi
