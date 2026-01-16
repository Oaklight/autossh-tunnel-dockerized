#!/bin/sh

# Test script to verify config file monitoring works correctly
# This simulates different ways editors modify files

CONFIG_DIR="./config"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
BACKUP_FILE="$CONFIG_DIR/config.yaml.backup"

echo "=== Config File Monitor Test ==="
echo ""

# Backup original config
if [ -f "$CONFIG_FILE" ]; then
	cp "$CONFIG_FILE" "$BACKUP_FILE"
	echo "✓ Backed up original config to $BACKUP_FILE"
else
	echo "✗ Config file not found at $CONFIG_FILE"
	exit 1
fi

echo ""
echo "Test 1: Direct modification (like vim/nano)"
echo "-------------------------------------------"
echo "# Test comment $(date)" >>"$CONFIG_FILE"
echo "✓ Appended test comment to config file"
echo "  Wait 5 seconds to see if monitor detects the change..."
sleep 5

echo ""
echo "Test 2: File replacement (like VSCode)"
echo "---------------------------------------"
cp "$BACKUP_FILE" "$CONFIG_FILE.tmp"
mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
echo "✓ Replaced config file using mv"
echo "  Wait 5 seconds to see if monitor detects the change..."
sleep 5

echo ""
echo "Test 3: Touch (attribute change)"
echo "---------------------------------"
touch "$CONFIG_FILE"
echo "✓ Touched config file"
echo "  Wait 5 seconds to see if monitor detects the change..."
sleep 5

echo ""
echo "=== Test Complete ==="
echo ""
echo "Check the autossh container logs to verify that config changes were detected:"
echo "  docker compose logs -f autossh"
echo ""
echo "To restore original config:"
echo "  cp $BACKUP_FILE $CONFIG_FILE"
