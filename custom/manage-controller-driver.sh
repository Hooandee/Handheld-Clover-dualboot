#!/bin/bash

set -u

DRIVER_NAME=UsbXbox360Dxe.efi

case "${1:-}" in
	install)
		source_file=${2:-}
		driver_dir=${3:-}
		config_source=${4:-}
		config_dir=${5:-}
		[ -s "$source_file" ] && [ -n "$driver_dir" ] || exit 1
		if [ -n "$config_source$config_dir" ]
		then
			[ -s "$config_source" ] && [ -n "$config_dir" ] || exit 1
		fi
		mkdir -p "$driver_dir" || exit 1
		target="$driver_dir/$DRIVER_NAME"
		stage="$driver_dir/.$DRIVER_NAME.$$"
		rm -f "$stage"
		if [ -n "$config_source" ]
		then
			mkdir -p "$config_dir" || exit 1
			config_target="$config_dir/config.ini"
			config_stage="$config_dir/.config.ini.$$"
			rm -f "$config_stage"
		fi
		if cp "$source_file" "$stage" \
			&& cmp -s "$source_file" "$stage" \
			&& { [ -z "$config_source" ] || cp "$config_source" "$config_stage"; } \
			&& { [ -z "$config_source" ] || cmp -s "$config_source" "$config_stage"; } \
			&& mv -f "$stage" "$target" \
			&& cmp -s "$source_file" "$target" \
			&& { [ -z "$config_source" ] || mv -f "$config_stage" "$config_target"; } \
			&& { [ -z "$config_source" ] || cmp -s "$config_source" "$config_target"; }
		then
			exit 0
		fi
		rm -f "$stage"
		[ -z "${config_stage:-}" ] || rm -f "$config_stage"
		exit 1
		;;
	remove)
		driver_dir=${2:-}
		[ -n "$driver_dir" ] || exit 1
		target="$driver_dir/$DRIVER_NAME"
		rm -f "$target" || exit 1
		[ ! -e "$target" ] || exit 1
		;;
	*)
		echo "usage: $0 install SOURCE DRIVER_DIR [CONFIG_SOURCE CONFIG_DIR] | remove DRIVER_DIR" >&2
		exit 2
		;;
esac
