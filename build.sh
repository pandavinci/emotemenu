#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMOTEMENU_VERSION="1.0.7"

# Auto-detect Vintage Story installation
if [ -z "$VINTAGE_STORY" ]; then
    if [ -d "$HOME/.var/app/at.vintagestory.VintageStory/config/VintagestoryData" ]; then
        # Flatpak (Linux)
        VINTAGE_STORY="$(find /var/lib/flatpak/app/at.vintagestory.VintageStory -path "*/files/extra/vintagestory" 2>/dev/null | head -1)"
        [ -z "$VINTAGE_STORY" ] && VINTAGE_STORY="$(find "$HOME/.local/share/flatpak/app/at.vintagestory.VintageStory" -path "*/files/extra/vintagestory" 2>/dev/null | head -1)"
    elif [ -d "$HOME/.config/VintagestoryData" ]; then
        VINTAGE_STORY="/usr/share/vintagestory"
    elif [ -d "$APPDATA/VintagestoryData" ] 2>/dev/null; then
        VINTAGE_STORY="$PROGRAMFILES/Vintagestory"
    fi
fi

# Auto-detect mods folder
if [ -z "$MODS_FOLDER" ]; then
    if [ -d "$HOME/.var/app/at.vintagestory.VintageStory/config/VintagestoryData/Mods" ]; then
        MODS_FOLDER="$HOME/.var/app/at.vintagestory.VintageStory/config/VintagestoryData/Mods"
    elif [ -d "$HOME/.config/VintagestoryData/Mods" ]; then
        MODS_FOLDER="$HOME/.config/VintagestoryData/Mods"
    elif [ -d "$APPDATA/VintagestoryData/Mods" ] 2>/dev/null; then
        MODS_FOLDER="$APPDATA/VintagestoryData/Mods"
    fi
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    if ! command -v dotnet &> /dev/null; then
        echo_error "dotnet SDK not found. Please install .NET 8 SDK."
        exit 1
    fi
    
    if [ ! -d "$VINTAGE_STORY" ]; then
        echo_error "Vintage Story not found at: $VINTAGE_STORY"
        echo_error "Set VINTAGE_STORY environment variable to your installation path."
        exit 1
    fi
    
    if [ ! -f "$VINTAGE_STORY/VintagestoryAPI.dll" ]; then
        echo_error "VintagestoryAPI.dll not found in $VINTAGE_STORY"
        exit 1
    fi
    
    echo_info "Prerequisites OK"
}

build_mod() {
    echo_info "Building emotemenu..."
    cd "$SCRIPT_DIR/mods/emotemenu"
    VINTAGE_STORY="$VINTAGE_STORY" dotnet build -c Debug --nologo -v q
    echo_info "Build complete"
}

package_mod() {
    cd "$SCRIPT_DIR"
    mkdir -p releases
    
    echo_info "Packaging EmoteMenu-${EMOTEMENU_VERSION}.zip..."
    rm -rf releases/staging
    mkdir -p releases/staging
    
    cp mods-dll/emotemenu.dll releases/staging/
    cp mods/emotemenu/modinfo.json releases/staging/
    
    if [ -d "mods/emotemenu/assets" ]; then
        cp -r mods/emotemenu/assets releases/staging/
    fi
    
    cd releases/staging
    rm -f "../EmoteMenu-${EMOTEMENU_VERSION}.zip"
    zip -r "../EmoteMenu-${EMOTEMENU_VERSION}.zip" . -q
    cd "$SCRIPT_DIR"
    rm -rf releases/staging
    
    echo_info "Package created: releases/EmoteMenu-${EMOTEMENU_VERSION}.zip"
}

install_mod() {
    if [ -z "$MODS_FOLDER" ]; then
        echo_warn "Mods folder not found, skipping install"
        return
    fi
    
    echo_info "Installing to mods folder..."
    
    # Remove old versions
    rm -f "$MODS_FOLDER"/EmoteMenu*.zip
    rm -f "$MODS_FOLDER"/RadialMenu*.zip
    
    cp "releases/EmoteMenu-${EMOTEMENU_VERSION}.zip" "$MODS_FOLDER/"
    
    echo_info "Installed: $MODS_FOLDER/EmoteMenu-${EMOTEMENU_VERSION}.zip"
}

run_tests() {
    echo_info "Running tests..."
    
    local zip_file="releases/EmoteMenu-${EMOTEMENU_VERSION}.zip"
    
    if [ ! -f "$zip_file" ]; then
        echo_error "[FAIL] Zip file not found"
        return 1
    fi
    echo_info "  [PASS] Zip file exists"
    
    if ! unzip -t "$zip_file" > /dev/null 2>&1; then
        echo_error "  [FAIL] Zip file is corrupt"
        return 1
    fi
    echo_info "  [PASS] Zip file is valid"
    
    if ! unzip -l "$zip_file" | grep -q "modinfo.json"; then
        echo_error "  [FAIL] Missing modinfo.json"
        return 1
    fi
    echo_info "  [PASS] Contains modinfo.json"
    
    if ! unzip -l "$zip_file" | grep -q "emotemenu.dll"; then
        echo_error "  [FAIL] Missing emotemenu.dll"
        return 1
    fi
    echo_info "  [PASS] Contains emotemenu.dll"
    
    if ! unzip -l "$zip_file" | grep -q "assets/"; then
        echo_warn "  [WARN] No assets folder"
    else
        echo_info "  [PASS] Contains assets"
    fi
    
    echo_info "All tests passed!"
}

show_help() {
    echo "EmoteMenu Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --build      Build the mod"
    echo "  --package    Create release zip"
    echo "  --install    Install to mods folder"
    echo "  --test       Run tests"
    echo "  --all        Do all of the above (default)"
    echo "  --help       Show this help"
}

main() {
    echo "=========================================="
    echo "  EmoteMenu Build Script"
    echo "=========================================="
    echo ""
    
    local do_build=false
    local do_package=false
    local do_install=false
    local do_test=false
    
    if [ $# -eq 0 ]; then
        do_build=true
        do_package=true
        do_install=true
        do_test=true
    else
        while [[ $# -gt 0 ]]; do
            case $1 in
                --build) do_build=true ;;
                --package) do_package=true ;;
                --install) do_install=true ;;
                --test) do_test=true ;;
                --all)
                    do_build=true
                    do_package=true
                    do_install=true
                    do_test=true
                    ;;
                --help) show_help; exit 0 ;;
                *) echo_error "Unknown option: $1"; show_help; exit 1 ;;
            esac
            shift
        done
    fi
    
    check_prerequisites
    
    $do_build && build_mod
    $do_package && package_mod
    $do_install && install_mod
    $do_test && run_tests
    
    echo ""
    echo_info "Done!"
}

main "$@"
