#!/bin/bash

# Linux Filesystem Hierarchy Cribsheet
# Add this to your ~/.bashrc or source it from a separate file

crib() {
  local target="$1"
  
  # Colors
  local BOLD='\033[1m'
  local BLUE='\033[0;34m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local NC='\033[0m' # No Color
  
  # Helper function to print section
  print_dir() {
    local dir="$1"
    local desc="$2"
    local details="$3"
    echo -e "${BOLD}${BLUE}${dir}${NC} - ${GREEN}${desc}${NC}"
    echo -e "${details}\n"
  }
  
  # Show usage
  show_usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo "  crib [PATH]              Show info about specific directory"
    echo "  crib .                   Show info about current directory"
    echo "  crib -r, --roots         List all root-level directories"
    echo "  crib -t, --trouble       Show troubleshooting commands"
    echo "  crib -h, --help          Show this help"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  crib /var/log            # Info about /var/log"
    echo "  crib .                   # Info about current dir"
    echo "  crib --roots             # List all root dirs"
  }
  
  # Show troubleshooting commands
  show_trouble() {
    echo -e "${BOLD}${CYAN}Common Troubleshooting Commands${NC}\n"
    
    echo -e "${BOLD}Disk Space Issues:${NC}"
    echo "  du -sh /var/log/*                    # Check log sizes"
    echo "  du -sh /var/lib/docker/*             # Check Docker usage"
    echo "  journalctl --disk-usage              # Check journal size"
    echo "  ncdu /var                            # Interactive disk usage"
    echo ""
    
    echo -e "${BOLD}Service Issues:${NC}"
    echo "  systemctl status servicename         # Check service status"
    echo "  journalctl -u servicename -f         # Tail service logs"
    echo "  systemctl cat servicename            # Show unit file"
    echo "  systemctl list-units --failed        # List failed services"
    echo ""
    
    echo -e "${BOLD}Network Issues:${NC}"
    echo "  cat /etc/hosts                       # Check hostname mappings"
    echo "  cat /etc/resolv.conf                 # Check DNS config"
    echo "  ip addr show                         # Show network interfaces"
    echo "  ss -tulpn                            # Show listening ports"
    echo "  journalctl -u systemd-networkd -f    # Watch network logs"
    echo ""
    
    echo -e "${BOLD}Boot Issues:${NC}"
    echo "  cat /proc/cmdline                    # Kernel boot parameters"
    echo "  dmesg | grep -i error                # Kernel errors"
    echo "  journalctl -b -p err                 # Boot errors"
    echo "  ls -lh /boot/                        # Check boot files"
    echo ""
    
    echo -e "${BOLD}Permission Issues:${NC}"
    echo "  namei -l /path/to/file               # Show permissions along path"
    echo "  getfacl /path/to/file                # Show ACLs"
    echo "  ls -lZ /path/to/file                 # Show SELinux context"
    echo ""
    
    echo -e "${BOLD}Process Issues:${NC}"
    echo "  ps aux | grep processname            # Find process"
    echo "  lsof -p PID                          # Files opened by process"
    echo "  strace -p PID                        # Trace system calls"
    echo "  pstree -p PID                        # Process tree"
  }
  
  # Show all root directories
  show_roots() {
    echo -e "${BOLD}${CYAN}Root-Level Directories${NC}\n"
    
    print_dir "/etc" "System Configuration" \
      "Config files: nginx, systemd, ssh, cron, apt sources"
    
    print_dir "/var" "Variable Data" \
      "/var/log - logs | /var/lib - app data (docker, postgres) | /var/cache - caches"
    
    print_dir "/usr" "User Binaries & Data" \
      "/usr/bin - programs | /usr/lib - libraries | /usr/local - custom installs"
    
    print_dir "/lib" "Essential Libraries" \
      "Shared libraries for /bin and /sbin | /lib/modules - kernel modules"
    
    print_dir "/sys" "Kernel & Hardware (virtual)" \
      "/sys/block - disks | /sys/class/net - network | /sys/devices - hardware tree"
    
    print_dir "/proc" "Process Info (virtual)" \
      "/proc/cpuinfo | /proc/meminfo | /proc/[PID]/ - process info"
    
    print_dir "/home" "User Home Directories" \
      "User files, configs (~/.bashrc, ~/.config/)"
    
    print_dir "/root" "Root User Home" \
      "Root's personal directory (not / itself)"
    
    print_dir "/boot" "Boot Files" \
      "Kernel (vmlinuz), initrd, GRUB config"
    
    print_dir "/tmp" "Temporary Files" \
      "Cleared on reboot, often tmpfs (RAM)"
    
    print_dir "/opt" "Optional Software" \
      "Third-party apps (Chrome, Sublime)"
    
    print_dir "/srv" "Service Data" \
      "/srv/www - web files | /srv/ftp - FTP files"
    
    print_dir "/mnt" "Temporary Mounts" \
      "Manual mount point for temporary filesystems"
    
    print_dir "/media" "Removable Media" \
      "Auto-mounted USB drives, CDs"
    
    print_dir "/dev" "Device Files" \
      "/dev/sda - disks | /dev/null - null device | /dev/random - RNG"
    
    print_dir "/bin → /usr/bin" "Essential Binaries" \
      "ls, cp, mv, cat, bash (symlinked on modern Ubuntu)"
    
    print_dir "/sbin → /usr/sbin" "System Binaries" \
      "init, mount, fdisk (symlinked on modern Ubuntu)"
  }
  
  # Get info about specific directory
  show_dir_info() {
    local dir="$1"
    
    # Normalize the path
    case "$dir" in
      /etc|/etc/*)
        print_dir "/etc" "System Configuration" \
          "${YELLOW}Common files:${NC}
  /etc/fstab               - filesystem mounts
  /etc/hosts               - hostname to IP mappings
  /etc/systemd/system/     - systemd service files
  /etc/nginx/              - nginx configuration
  /etc/ssh/sshd_config     - SSH daemon config
  /etc/cron.d/             - cron jobs
  /etc/environment         - system environment variables
  /etc/apt/sources.list    - package repositories"
        ;;
        
      /var|/var/*)
        print_dir "/var" "Variable Data (changes during operation)" \
          "${YELLOW}Common subdirs:${NC}
  /var/log/                - all logs (syslog, auth.log, nginx/)
  /var/lib/                - persistent app data
    /var/lib/docker/       - Docker images/containers/volumes
    /var/lib/postgresql/   - PostgreSQL data
    /var/lib/clickhouse/   - ClickHouse data
  /var/cache/              - application caches
  /var/tmp/                - temp files (preserved on reboot)
  
${YELLOW}Troubleshooting:${NC}
  du -sh /var/log/*        - check log sizes
  journalctl --vacuum-time=7d - clean old journals"
        ;;
        
      /usr|/usr/*)
        print_dir "/usr" "User Programs & Read-Only Data" \
          "${YELLOW}Common subdirs:${NC}
  /usr/bin/                - user commands (python, git, curl)
  /usr/sbin/               - system commands (nginx, usermod)
  /usr/lib/                - libraries
  /usr/local/bin/          - your custom scripts
  /usr/share/doc/          - documentation
  /usr/share/man/          - manual pages
  /usr/include/            - C/C++ header files"
        ;;
        
      /lib|/lib64|/lib/*)
        print_dir "/lib" "Essential System Libraries" \
          "${YELLOW}Contains:${NC}
  Shared libraries (.so files)
  /lib/modules/            - kernel modules
  /lib/systemd/            - systemd helpers
  /lib64/                  - 64-bit libraries
  
${YELLOW}Note:${NC} Critical for boot - don't touch unless you know what you're doing"
        ;;
        
      /sys|/sys/*)
        print_dir "/sys" "Kernel & Hardware Info (Virtual FS)" \
          "${YELLOW}Common paths:${NC}
  /sys/block/              - block devices
  /sys/class/net/          - network interfaces
  /sys/devices/            - device tree
  /sys/fs/                 - filesystem info
  
${YELLOW}Examples:${NC}
  cat /sys/class/net/eth0/address  - get MAC
  cat /sys/block/sda/size          - disk size in sectors"
        ;;
        
      /proc|/proc/*)
        print_dir "/proc" "Process & Kernel Runtime Info (Virtual)" \
          "${YELLOW}Common files:${NC}
  /proc/cpuinfo            - CPU information
  /proc/meminfo            - memory details
  /proc/[PID]/             - process-specific info
  /proc/sys/               - kernel tunables
  
${YELLOW}Examples:${NC}
  cat /proc/meminfo | grep MemTotal
  cat /proc/cmdline        - kernel boot params"
        ;;
        
      /home|/home/*)
        print_dir "/home" "User Home Directories" \
          "${YELLOW}Contains:${NC}
  /home/username/          - user's personal files
  ~/.bashrc                - bash config
  ~/.config/               - app configs
  ~/.local/                - user-local programs
  ~/.ssh/                  - SSH keys
  
${YELLOW}Note:${NC} Often on separate partition for easy OS reinstall"
        ;;
        
      /root|/root/*)
        print_dir "/root" "Root User's Home Directory" \
          "${YELLOW}Contains:${NC}
  Root's personal files and scripts
  Not accessible to regular users
  
${YELLOW}Note:${NC} Different from / (filesystem root)"
        ;;
        
      /boot|/boot/*)
        print_dir "/boot" "Boot Files" \
          "${YELLOW}Contains:${NC}
  /boot/vmlinuz-*          - Linux kernel
  /boot/initrd.img-*       - initial ramdisk
  /boot/grub/              - GRUB bootloader config
  
${YELLOW}Note:${NC} Critical for system boot; often separate partition"
        ;;
        
      /tmp|/tmp/*)
        print_dir "/tmp" "Temporary Files" \
          "${YELLOW}Usage:${NC}
  Temporary files for all users
  Often cleared on reboot
  Often mounted as tmpfs (in RAM)
  
${YELLOW}Permissions:${NC} 1777 (world-writable with sticky bit)"
        ;;
        
      /opt|/opt/*)
        print_dir "/opt" "Optional/Third-Party Software" \
          "${YELLOW}Common installs:${NC}
  /opt/google/chrome/      - Chrome
  /opt/sublime_text/       - Sublime Text
  Commercial/proprietary software
  Self-contained applications"
        ;;
        
      /srv|/srv/*)
        print_dir "/srv" "Service Data" \
          "${YELLOW}Usage:${NC}
  /srv/www/                - web server files
  /srv/ftp/                - FTP files
  /srv/git/                - Git repositories
  
${YELLOW}Note:${NC} Not heavily used on Ubuntu; /var often preferred"
        ;;
        
      /mnt|/mnt/*)
        print_dir "/mnt" "Temporary Mount Points" \
          "${YELLOW}Usage:${NC}
  Manual temporary mounts
  Mount external drives for maintenance
  
${YELLOW}Example:${NC}
  sudo mount /dev/sdb1 /mnt
  # do work
  sudo umount /mnt"
        ;;
        
      /media|/media/*)
        print_dir "/media" "Removable Media (Auto-mount)" \
          "${YELLOW}Contains:${NC}
  /media/username/USB/     - auto-mounted USB drives
  /media/username/CDROM/   - CD/DVD drives
  
${YELLOW}Note:${NC} Desktop environments auto-mount removable media here"
        ;;
        
      /dev|/dev/*)
        print_dir "/dev" "Device Files" \
          "${YELLOW}Common devices:${NC}
  /dev/sda, /dev/sdb       - hard drives
  /dev/null                - null device (discards data)
  /dev/random              - random number generator
  /dev/tty*                - terminals
  
${YELLOW}Examples:${NC}
  dd if=/dev/zero of=file bs=1M count=100
  cat /dev/null > file.log  - truncate file"
        ;;
        
      /bin|/sbin)
        print_dir "$dir → /usr${dir}" "Essential Binaries (Symlinked)" \
          "${YELLOW}Note:${NC} On modern Ubuntu, these are symlinks to /usr${dir}
  
/bin  - user commands (ls, cp, mv, cat, bash)
/sbin - system commands (init, mount, fdisk)"
        ;;
        
      /snap|/snap/*)
        print_dir "/snap" "Snap Packages (Ubuntu-specific)" \
          "${YELLOW}Contains:${NC}
  Snap package installations
  /var/snap/               - snap data
  
${YELLOW}Note:${NC} Ubuntu's containerized package format"
        ;;
        
      *)
        echo -e "${YELLOW}Unknown directory: $dir${NC}"
        echo "Try: crib --roots to see all standard directories"
        return 1
        ;;
    esac
  }
  
  # Main logic
  case "$target" in
    -h|--help|"")
      show_usage
      ;;
    -r|--roots)
      show_roots
      ;;
    -t|--trouble)
      show_trouble
      ;;
    .)
      show_dir_info "$(pwd)"
      ;;
    *)
      # If it starts with /, treat as absolute path
      # Otherwise, treat as relative to current dir
      if [[ "$target" == /* ]]; then
        show_dir_info "$target"
      else
        show_dir_info "$(pwd)/$target"
      fi
      ;;
  esac
}

# Bash completion for crib command
_crib_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="-h --help -r --roots -t --trouble"
  
  if [[ ${cur} == -* ]] ; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
  fi
  
  # Complete directory names
  COMPREPLY=( $(compgen -d -- ${cur}) )
  return 0
}

complete -F _crib_completion crib
