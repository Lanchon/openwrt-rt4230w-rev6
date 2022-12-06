set -e

TMP_DIR="/tmp/lanchon"
#TMP_DIR="$(mktemp -d "${TMP_DIR}-XXXXXX")"

BAK_NAME="ubi-backup"
BAK_FILE="${BAK_NAME}.tar"

mkdir -p "$TMP_DIR/$BAK_NAME"
rm -f "$TMP_DIR/$BAK_FILE"

ubiattach -m 20 || true
ubiattach -m 21 || true

echo

echo "creating backup files:"
cd /dev
for UBI_DEV in ubi[0-9]*_[0-9]*; do
	UBI_NAME=$( cat "/sys/class/ubi/$UBI_DEV/name" )
	UBI_BAK_FILE="${UBI_DEV}-${UBI_NAME}.gz"
	echo "backing up ${UBI_DEV} to '$UBI_BAK_FILE'"
	gzip -c "${UBI_DEV}" >"$TMP_DIR/$BAK_NAME/$UBI_BAK_FILE" || echo " -> ${UBI_DEV}: backup failed"
done
cd "$TMP_DIR/$BAK_NAME"
ubinfo -a >ubi-info.txt

echo

echo "tarring backup files to '$TMP_DIR/$BAK_FILE'"
tar -cf "../$BAK_FILE" * || echo "error: tar failed"
rm -rf "../$BAK_NAME"

echo

ubidetach -m 21 || true
ubidetach -m 20 || true

