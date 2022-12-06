set -e

TMP_DIR="/tmp/lanchon"
#TMP_DIR="$(mktemp -d "${TMP_DIR}-XXXXXX")"

BAK_NAME="mtd-backup"
BAK_FILE="${BAK_NAME}.tar"

mkdir -p "$TMP_DIR/$BAK_NAME"
rm -f "$TMP_DIR/$BAK_FILE"

echo

echo "creating backup files:"
cd "$TMP_DIR/$BAK_NAME"
tail -n +2 /proc/mtd | while read; do
	MTD_DEV=$( echo "${REPLY}" | cut -f 1 -d : )
	MTD_NAME=$( echo "${REPLY}" | cut -f 2 -d \" )
	MTD_BAK_FILE="${MTD_DEV}-${MTD_NAME}.gz"
	echo "backing up ${MTD_DEV} to '$MTD_BAK_FILE'"
	gzip -c "/dev/${MTD_DEV}" >"$MTD_BAK_FILE" || echo " -> ${MTD_DEV}: backup failed"
done

echo

echo "tarring backup files to '$TMP_DIR/$BAK_FILE'"
tar -cf "../$BAK_FILE" * || echo "error: tar failed"
rm -rf "../$BAK_NAME"

echo

