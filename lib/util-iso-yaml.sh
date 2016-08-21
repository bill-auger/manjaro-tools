#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import ${LIBDIR}/util-iso.sh
import ${LIBDIR}/util-iso-calamares.sh

check_yaml(){
	result=$(python -c 'import yaml,sys;yaml.safe_load(sys.stdin)' < $1)
	[[ $? -ne 0 ]] && error "yaml error: %s [msg: %s]"  "$1"
}

write_netgroup_yaml(){
	echo "- name: '$1'" > "$2"
	echo "  description: '$1'" >> "$2"
	echo "  selected: false" >> "$2"
	echo "  hidden: false" >> "$2"
	echo "  packages:" >> "$2"
	for p in ${packages[@]};do
		echo "       - $p" >> "$2"
	done
	check_yaml "$2"
}

prepare_check(){
	profile=$1
	edition=$(get_edition ${profile})
	profile_dir=${run_dir}/${edition}/${profile}
	check_profile
	load_profile_config "${profile_dir}/profile.conf"

	yaml_dir=${cache_dir_netinstall}/${profile}
	work_dir=${chroots_iso}/${profile}/${target_arch}

	prepare_dir "${yaml_dir}"
	chown "${OWNER}:${OWNER}" "${yaml_dir}"
}

write_calamares_yaml(){
	local preset=${work_dir}/root-image/etc/mkinitcpio.d/${kernel}
	[[ -f ${preset}.preset ]] || die "The profile needs to be built at least one time!"
	configure_calamares "${yaml_dir}" "${preset}"
	for conf in "${yaml_dir}"/etc/calamares/modules/*.conf "${yaml_dir}"/etc/calamares/settings.conf; do
		check_yaml "$conf"
	done
}

make_profile_yaml(){
	prepare_check "$1"
	load_pkgs "${profile_dir}/Packages-Root"
	yaml="${yaml_dir}/Packages-Root-${target_arch}-${initsys}.yaml"
	write_netgroup_yaml "$1" "${yaml}"
	if [[ -f "${packages_custom}" ]]; then
		load_pkgs "${packages_custom}"
		yaml="${yaml_dir}/${packages_custom##*/}-${target_arch}-${initsys}.yaml"
		write_netgroup_yaml "$1" "${yaml}"
	fi
	${calamares} && write_calamares_yaml "$1"
	user_own "${yaml_dir}"
	reset_profile
	unset yaml
	unset yaml_dir
}