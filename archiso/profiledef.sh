#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="pond-installer"
iso_label="POND_INSTALLER_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Butterfly"
iso_application="Pond Installer"
iso_version="${POND_INSTALLER_VERSION:-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)}"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.grub')
pacman_conf="pacman.conf"
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zlzma,109' -E 'ztailpacking')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/pond-installer"]="0:0:440"
  ["/usr/local/bin/pond-installer"]="0:0:755"
)
