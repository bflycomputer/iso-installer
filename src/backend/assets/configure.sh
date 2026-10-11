set -euo pipefail

ZONEINFO="/usr/share/zoneinfo/${POND_TIMEZONE:-UTC}"
if [ ! -f "$ZONEINFO" ]; then
    echo "[timezone] Unknown system timezone '$POND_TIMEZONE'; using UTC" >&2
    ZONEINFO=/usr/share/zoneinfo/UTC
fi
ln -sf "$ZONEINFO" /etc/localtime
hwclock --systohc
printf '%s\n' "$POND_HOSTNAME" > /etc/hostname

pacman-key --init
pacman-key --populate archlinux pond

useradd -m -G wheel,audio "$POND_USERNAME"

printf '%s:%s\n' "$POND_USERNAME" "$POND_PASSWORD" | chpasswd

visudo --check --file=/etc/sudoers
