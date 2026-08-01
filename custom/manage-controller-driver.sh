#!/bin/bash

set -u

DRIVER_NAME=UsbXbox360Dxe.efi

case "${1:-}" in
	install)
		source_file=${2:-}
		driver_dir=${3:-}
		[ -s "$source_file" ] && [ -n "$driver_dir" ] || exit 1
		mkdir -p "$driver_dir" || exit 1
		target="$driver_dir/$DRIVER_NAME"
		stage="$driver_dir/.$DRIVER_NAME.$$"
		rm -f "$stage"
		cp "$source_file" "$stage" \
			&& cmp -s "$source_file" "$stage" \
			&& mv -f "$stage" "$target" \
			&& cmp -s "$source_file" "$target" \
			&& exit 0
		rm -f "$stage"
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
		echo "usage: $0 install SOURCE DRIVER_DIR | remove DRIVER_DIR" >&2
		exit 2
		;;
esac
