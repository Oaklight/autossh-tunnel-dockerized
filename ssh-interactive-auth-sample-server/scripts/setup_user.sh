#!/bin/bash
set -e

USER=testuser
PASS=testpass

# Create user if not exists
if ! id "$USER" &>/dev/null; then
	useradd -m -s /bin/bash "$USER"
	echo "$USER:$PASS" | chpasswd
	echo "User $USER created with password $PASS"
fi

# Setup Google Authenticator
# -t: Time-based
# -d: Disallow reuse of same token
# -f: Force file creation
# -r 3 -R 30: Rate limit 3 logins every 30s
# -w 3: Window size 3 (allows for some time skew)
# -C: No confirmation needed
su - "$USER" -c "google-authenticator -t -d -f -r 3 -R 30 -w 3 -C"

echo "Google Authenticator configured for $USER"
