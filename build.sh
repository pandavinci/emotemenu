#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMOTEMENU_VERSION="1.0.7"
RADIALMENU_VERSION="1.0.0"

# Auto-detect Vintage Story installation
if [ -z "$VINTAGE_STORY" ]; then
    # Try common paths
    if [ -d "$HOME/.var/app/at.vintagestory.VintageStory/config/VintagestoryData" ]; then
        # Flatpak (Linux)
        VINTAGE_STORY="$(find /var/lib/flatpak/app/at.vintagestory.VintageStory -path "*/files/extra/vintagestory" 2>/dev/null | head -1)"
        [ -z "$VINTAGE_STORY" ] && VINTAGE_STORY="$(find "$HOME/.local/share/flatpak/app/at.vintagestory.VintageStory" -path "*/files/extra/vintagestory" 2>/dev/null | head -1)"
    elif [ -d "$HOME/.config/VintagestoryData" ]; then
        # Native Linux install
        VINTAGE_STORY="/usr/share/vintagestory"
    elif [ -d "$APPDATA/VintagestoryData" ] 2>/dev/null; then
        # Windows
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
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

# Build mods
build_mods() {
    echo_info "Building radialmenu..."
    cd "$SCRIPT_DIR/mods/radialmenu"
    VINTAGE_STORY="$VINTAGE_STORY" dotnet build -c Debug --nologo -v q
    
    echo_info "Building emotemenu..."
    cd "$SCRIPT_DIR/mods/emotemenu"
    VINTAGE_STORY="$VINTAGE_STORY" dotnet build -c Debug --nologo -v q
    
    echo_info "Build complete"
}

# Package mods (two separate zips)
package_mod() {
    cd "$SCRIPT_DIR"
    mkdir -p releases
    
    # Package radialmenu
    echo_info "Packaging RadialMenu-${RADIALMENU_VERSION}.zip..."
    rm -rf releases/staging
    mkdir -p releases/staging
    cp mods-dll/radialmenu.dll releases/staging/
    cp mods/radialmenu/modinfo.json releases/staging/
    cd releases/staging
    rm -f "../RadialMenu-${RADIALMENU_VERSION}.zip"
    zip -r "../RadialMenu-${RADIALMENU_VERSION}.zip" . -q
    cd "$SCRIPT_DIR"
    rm -rf releases/staging
    
    # Package emotemenu
    echo_info "Packaging EmoteMenu-${EMOTEMENU_VERSION}.zip..."
    rm -rf releases/staging
    mkdir -p releases/staging
    cp mods-dll/emotemenu.dll releases/staging/
    cp mods/emotemenu/modinfo.json releases/staging/
    if [ -d "mods/emotemenu/assets" ]; then
        cp -r mods/emotemenu/assets releases/staging/
    else
        echo_warn "No assets folder found - mod may not work correctly"
    fi
    cd releases/staging
    rm -f "../EmoteMenu-${EMOTEMENU_VERSION}.zip"
    zip -r "../EmoteMenu-${EMOTEMENU_VERSION}.zip" . -q
    cd "$SCRIPT_DIR"
    rm -rf releases/staging
    
    echo_info "Packages created:"
    echo_info "  - releases/RadialMenu-${RADIALMENU_VERSION}.zip"
    echo_info "  - releases/EmoteMenu-${EMOTEMENU_VERSION}.zip"
}

# Install to mods folder
install_mod() {
    echo_info "Installing to mods folder..."
    
    if [ ! -d "$MODS_FOLDER" ]; then
        echo_error "Mods folder not found: $MODS_FOLDER"
        exit 1
    fi
    
    # Remove old versions
    rm -f "$MODS_FOLDER"/EmoteMenu-*.zip
    rm -f "$MODS_FOLDER"/RadialMenu-*.zip
    
    # Copy new versions
    cp "releases/RadialMenu-${RADIALMENU_VERSION}.zip" "$MODS_FOLDER/"
    cp "releases/EmoteMenu-${EMOTEMENU_VERSION}.zip" "$MODS_FOLDER/"
    
    echo_info "Installed:"
    echo_info "  - $MODS_FOLDER/RadialMenu-${RADIALMENU_VERSION}.zip"
    echo_info "  - $MODS_FOLDER/EmoteMenu-${EMOTEMENU_VERSION}.zip"
}

# Run tests
run_tests() {
    echo_info "Running tests..."
    
    local errors=0
    
    # Test both zips
    for mod in "RadialMenu-${RADIALMENU_VERSION}" "EmoteMenu-${EMOTEMENU_VERSION}"; do
        local zip_file="releases/${mod}.zip"
        
        echo_info "Testing ${mod}..."
        
        # Test: Zip exists
        if [ -f "$zip_file" ]; then
            echo_info "  [PASS] Zip file exists"
        else
            echo_error "  [FAIL] Zip file not found"
            ((errors++))
            continue
        fi
        
        # Test: Zip is valid
        if unzip -t "$zip_file" &> /dev/null; then
            echo_info "  [PASS] Zip file is valid"
        else
            echo_error "  [FAIL] Zip file is corrupted"
            ((errors++))
        fi
        
        # Test: Contains modinfo.json
        if unzip -l "$zip_file" | grep -q "modinfo.json"; then
            echo_info "  [PASS] Contains modinfo.json"
        else
            echo_error "  [FAIL] Missing modinfo.json"
            ((errors++))
        fi
        
        # Test: modinfo.json is valid JSON
        if unzip -p "$zip_file" modinfo.json | python3 -m json.tool &> /dev/null; then
            echo_info "  [PASS] modinfo.json is valid JSON"
        else
            echo_error "  [FAIL] modinfo.json is invalid JSON"
            ((errors++))
        fi
        
        # Test: Contains exactly one DLL
        local dll_count=$(unzip -l "$zip_file" | grep -c "\.dll$" || true)
        if [ "$dll_count" -eq 1 ]; then
            echo_info "  [PASS] Contains exactly 1 DLL"
        else
            echo_error "  [FAIL] Contains $dll_count DLLs (expected 1)"
            ((errors++))
        fi
    done
    
    # Test emotemenu specific: Assets exist
    local emotemenu_zip="releases/EmoteMenu-${EMOTEMENU_VERSION}.zip"
    if unzip -l "$emotemenu_zip" | grep -q "assets/emotemenu/textures/"; then
        echo_info "  [PASS] EmoteMenu contains texture assets"
    else
        echo_error "  [FAIL] EmoteMenu missing texture assets"
        ((errors++))
    fi
    
    # Test: Check installed in mods folder
    if [ -f "$MODS_FOLDER/RadialMenu-${RADIALMENU_VERSION}.zip" ] && [ -f "$MODS_FOLDER/EmoteMenu-${EMOTEMENU_VERSION}.zip" ]; then
        echo_info "  [PASS] Both mods installed in game folder"
    else
        echo_warn "  [SKIP] Mods not installed (run with --install)"
    fi
    
    echo ""
    if [ $errors -eq 0 ]; then
        echo_info "All tests passed!"
        return 0
    else
        echo_error "$errors test(s) failed"
        return 1
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build      Build the mods"
    echo "  --package    Package into zips"
    echo "  --install    Install to mods folder"
    echo "  --test       Run tests"
    echo "  --all        Do everything (default)"
    echo "  --help       Show this help"
    echo ""
    echo "Environment variables:"
    echo "  VINTAGE_STORY    Path to Vintage Story installation"
    echo ""
}

# Main
main() {
    local do_build=false
    local do_package=false
    local do_install=false
    local do_test=false
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        do_build=true
        do_package=true
        do_install=true
        do_test=true
    else
        for arg in "$@"; do
            case $arg in
                --build)   do_build=true ;;
                --package) do_package=true ;;
                --install) do_install=true ;;
                --test)    do_test=true ;;
                --all)
                    do_build=true
                    do_package=true
                    do_install=true
                    do_test=true
                    ;;
                --help)
                    show_help
                    exit 0
                    ;;
                *)
                    echo_error "Unknown option: $arg"
                    show_help
                    exit 1
                    ;;
            esac
        done
    fi
    
    echo "=========================================="
    echo "  EmoteMenu Build Script"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    
    $do_build && build_mods
    $do_package && package_mod
    $do_install && install_mod
    $do_test && run_tests
    
    echo ""
    echo_info "Done!"
}

main "$@"
