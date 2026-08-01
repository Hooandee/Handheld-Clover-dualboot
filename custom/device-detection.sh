#!/bin/bash

detect_native_resolution() {
	local drm_root=${CLOVER_DRM_ROOT:-/sys/class/drm}
	local modes res w h
	for modes in "$drm_root"/*eDP*/modes "$drm_root"/*DSI*/modes "$drm_root"/*LVDS*/modes
	do
		[ -f "$modes" ] || continue
		res=$(head -n1 "$modes" 2> /dev/null)
		case "$res" in *x*) ;; *) continue ;; esac
		w=${res%%x*}
		h=${res##*x}
		case "$w" in ''|*[!0-9]*) continue ;; esac
		case "$h" in ''|*[!0-9]*) continue ;; esac
		[ "$w" -gt 0 ] && [ "$h" -gt 0 ] || continue
		if [ "$h" -gt "$w" ]
		then
			printf '%sx%s\n' "$h" "$w"
		else
			printf '%sx%s\n' "$w" "$h"
		fi
		return 0
	done
	return 1
}

controller_driver_enabled() {
	local policy=$1 noninteractive=${2:-0} answer=${3:-}
	case "$policy" in
		xpad) printf '%s\n' yes ;;
		ask|"")
			case "$noninteractive:$answer" in
				0:y|0:Y|0:s|0:S) printf '%s\n' yes ;;
				*) printf '%s\n' no ;;
			esac
			;;
		*) printf '%s\n' no ;;
	esac
}

resolve_install_profile() {
	local board=$1 product=$2 family=${3:-} vendor=${4:-}
	local match name fallback policy resolution source
	match=$(lookup_device "$board" "$product" "$family" "$vendor")
	if [ -n "$match" ]
	then
		policy=${match##*|}
		match=${match%|*}
		fallback=${match##*|}
		name=${match%|*}
	else
		name="Generic handheld"
		fallback=""
		policy=ask
	fi

	resolution=$(detect_native_resolution)
	if [ -n "$resolution" ]
	then
		source=drm
	elif [ -n "$fallback" ]
	then
		resolution=$fallback
		source=registry
	else
		source=none
	fi
	printf '%s|%s|%s|%s\n' "$name" "$resolution" "$source" "$policy"
}
