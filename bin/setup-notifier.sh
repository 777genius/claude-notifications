#!/bin/bash
# setup-notifier.sh - Auto-setup notification utilities for cross-platform support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NOTIFIER_DIR="$SCRIPT_DIR"
TERMINAL_NOTIFIER_VERSION="2.0.0"
TERMINAL_NOTIFIER_URL="https://github.com/julienXX/terminal-notifier/releases/download/${TERMINAL_NOTIFIER_VERSION}/terminal-notifier-${TERMINAL_NOTIFIER_VERSION}.zip"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

# Check if terminal-notifier is already available
check_terminal_notifier() {
  # Check system-wide installation
  if command -v terminal-notifier &> /dev/null; then
    echo "system"
    return 0
  fi

  # Check bundled installation
  local bundled="$NOTIFIER_DIR/terminal-notifier.app/Contents/MacOS/terminal-notifier"
  if [[ -x "$bundled" ]]; then
    echo "bundled"
    return 0
  fi

  echo "none"
  return 1
}

# Download and install terminal-notifier for macOS
install_terminal_notifier() {
  echo -e "${BLUE}📥 Downloading terminal-notifier...${NC}"

  local temp_dir=$(mktemp -d)
  local zip_file="$temp_dir/terminal-notifier.zip"

  # Download
  if command -v curl &> /dev/null; then
    curl -L -o "$zip_file" "$TERMINAL_NOTIFIER_URL" 2>/dev/null || {
      echo -e "${RED}✗ Failed to download terminal-notifier${NC}"
      rm -rf "$temp_dir"
      return 1
    }
  elif command -v wget &> /dev/null; then
    wget -O "$zip_file" "$TERMINAL_NOTIFIER_URL" 2>/dev/null || {
      echo -e "${RED}✗ Failed to download terminal-notifier${NC}"
      rm -rf "$temp_dir"
      return 1
    }
  else
    echo -e "${RED}✗ Neither curl nor wget found. Cannot download terminal-notifier.${NC}"
    rm -rf "$temp_dir"
    return 1
  fi

  # Extract
  echo -e "${BLUE}📦 Extracting...${NC}"
  unzip -q "$zip_file" -d "$temp_dir" || {
    echo -e "${RED}✗ Failed to extract terminal-notifier${NC}"
    rm -rf "$temp_dir"
    return 1
  }

  # Move to bin directory
  mv "$temp_dir/terminal-notifier.app" "$NOTIFIER_DIR/" || {
    echo -e "${RED}✗ Failed to install terminal-notifier${NC}"
    rm -rf "$temp_dir"
    return 1
  }

  # Cleanup
  rm -rf "$temp_dir"

  echo -e "${GREEN}✓ terminal-notifier installed successfully${NC}"
  return 0
}

# Setup macOS notifications
setup_macos() {
  echo -e "${BLUE}🍎 Setting up macOS notifications...${NC}"

  local status=$(check_terminal_notifier)

  case "$status" in
    system)
      echo -e "${GREEN}✓ Using system terminal-notifier${NC}"
      return 0
      ;;
    bundled)
      echo -e "${GREEN}✓ Using bundled terminal-notifier${NC}"
      return 0
      ;;
    none)
      echo -e "${YELLOW}⚠ terminal-notifier not found${NC}"
      echo -e "${BLUE}Installing terminal-notifier for reliable notifications...${NC}"

      if install_terminal_notifier; then
        return 0
      else
        echo -e "${YELLOW}⚠ Could not install terminal-notifier automatically${NC}"
        echo -e "${YELLOW}For best results, install manually:${NC}"
        echo -e "  ${BLUE}brew install terminal-notifier${NC}"
        echo -e "${YELLOW}Plugin will use osascript as fallback (may not work in all terminals)${NC}"
        return 1
      fi
      ;;
  esac
}

# Setup Linux notifications
setup_linux() {
  echo -e "${BLUE}🐧 Setting up Linux notifications...${NC}"

  if command -v notify-send &> /dev/null; then
    echo -e "${GREEN}✓ notify-send is available${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠ notify-send not found${NC}"
    echo -e "${YELLOW}Install libnotify for desktop notifications:${NC}"
    echo -e "  Ubuntu/Debian: ${BLUE}sudo apt install libnotify-bin${NC}"
    echo -e "  Fedora/RHEL:   ${BLUE}sudo dnf install libnotify${NC}"
    return 1
  fi
}

# Setup Windows notifications
setup_windows() {
  echo -e "${BLUE}🪟 Setting up Windows notifications...${NC}"

  if command -v powershell.exe &> /dev/null; then
    echo -e "${GREEN}✓ PowerShell is available${NC}"
    return 0
  else
    echo -e "${RED}✗ PowerShell not found (unusual for Windows)${NC}"
    return 1
  fi
}

# Main setup
main() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Claude Notifications Plugin Setup${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  local os=$(detect_os)

  case "$os" in
    macos)
      setup_macos
      ;;
    linux)
      setup_linux
      ;;
    windows)
      setup_windows
      ;;
    *)
      echo -e "${RED}✗ Unsupported operating system${NC}"
      return 1
      ;;
  esac

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Setup complete!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
