#!/bin/bash

usage() {
    echo "Usage: $0 -t <type> -s <server> -r <remote_path> -m <mount_point> [-u <username>] [-p <password>]"
    echo "Options:"
    echo "  -t, --type <type>        Mount type (nfs/smb)"
    echo "  -s, --server <server>    Server address"
    echo "  -r, --remote <path>      Remote path/share"
    echo "  -m, --mount <path>       Local mount point"
    echo "  -u, --user <username>    Username (for SMB)"
    echo "  -p, --pass <password>    Password (for SMB)"
    echo "  -h, --help              Show this help message"
    exit 1
}

setup_mount() {
    # Parse arguments
    MOUNT_TYPE=""
    SERVER=""
    REMOTE_PATH=""
    MOUNT_POINT=""
    USERNAME=""
    PASSWORD=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -t|--type)
                MOUNT_TYPE="$2"
                shift 2
                ;;
            -s|--server)
                SERVER="$2"
                shift 2
                ;;
            -r|--remote)
                REMOTE_PATH="$2"
                shift 2
                ;;
            -m|--mount)
                MOUNT_POINT="$2"
                shift 2
                ;;
            -u|--user)
                USERNAME="$2"
                shift 2
                ;;
            -p|--pass)
                PASSWORD="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$MOUNT_TYPE" ] || [ -z "$SERVER" ] || [ -z "$MOUNT_POINT" ]; then
        echo "Error: Missing required arguments"
        usage
    fi

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root (sudo)"
        exit 1
    fi

    # Validate mount type
    if [ "$MOUNT_TYPE" != "nfs" ] && [ "$MOUNT_TYPE" != "smb" ]; then
        echo "Error: Mount type must be 'nfs' or 'smb'"
        exit 1
    fi

    # Create mount point if it doesn't exist
    mkdir -p "$MOUNT_POINT"

    # Get current user's UID and GID
    CURRENT_UID=$(id -u "$SUDO_USER")
    CURRENT_GID=$(id -g "$SUDO_USER")

    # Function to check if entry already exists in fstab
    check_fstab() {
        local mount_point="$1"
        grep -q "^[^#].*$mount_point" /etc/fstab
        return $?
    }

    # Setup based on mount type
    if [ "$MOUNT_TYPE" = "nfs" ]; then
        # Install NFS client only if mount.nfs is not available
        if ! type mount.nfs > /dev/null 2>&1; then
            apt-get update
            apt-get install -y nfs-common
        fi

        FSTAB_ENTRY="${SERVER}:${REMOTE_PATH} ${MOUNT_POINT} nfs defaults,_netdev,user 0 0"
    else
        # Install CIFS utils only if mount.cifs is not available
       # if ! type mount.cifs > /dev/null 2>&1; then
       #     apt-get update
       #     apt-get install -y cifs-utils
      #  fi

        # Create credentials file for SMB
        if [ -n "$USERNAME" ]; then
            CREDS_FILE="/etc/samba/.credentials_$(echo "${SERVER}${REMOTE_PATH}" | sed 's/[^a-zA-Z0-9]/_/g')"
            echo "username=$USERNAME" > "$CREDS_FILE"
            echo "password=$PASSWORD" >> "$CREDS_FILE"
            chmod 600 "$CREDS_FILE"

            FSTAB_ENTRY="//${SERVER}${REMOTE_PATH} ${MOUNT_POINT} cifs credentials=${CREDS_FILE},_netdev,uid=${CURRENT_UID},gid=${CURRENT_GID},file_mode=0644,dir_mode=0755 0 0"
        else
            FSTAB_ENTRY="//${SERVER}${REMOTE_PATH} ${MOUNT_POINT} cifs username=guest,password=,_netdev,uid=${CURRENT_UID},gid=${CURRENT_GID},file_mode=0644,dir_mode=0755 0 0"
        fi
    fi

    # Add to fstab if not already present
    if ! check_fstab "$MOUNT_POINT"; then
        echo "$FSTAB_ENTRY" >> /etc/fstab
        echo "Added mount entry to /etc/fstab"
    else
        echo "Mount point already exists in /etc/fstab"
    fi

    # Test the mount
    echo "Testing mount..."
    mount -a

    if mountpoint -q "$MOUNT_POINT"; then
        echo "Mount successful!"
        echo "The share will be automatically mounted on system startup"
    else
        echo "Mount failed. Please check your settings and try again"
        echo "You may need to manually edit /etc/fstab to fix any issues"
    fi
}

# Only run if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    setup_mount "$@"
fi
