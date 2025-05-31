#!/bin/bash
# this_file: recovery_trackpad.sh

echo "🚑 Dragoboo Recovery Script"
echo "=========================="
echo "This script restores your trackpad/mouse to default macOS settings"
echo "if they got stuck in slow mode due to a Dragoboo crash."
echo ""

# Check current problematic settings
echo "🔍 Checking current settings..."

TRACKPAD_SCALING=$(defaults read -g com.apple.trackpad.scaling 2>/dev/null || echo "DEFAULT")
MOUSE_SCALING=$(defaults read -g com.apple.mouse.scaling 2>/dev/null || echo "DEFAULT")
TRACKPAD_ACCEL=$(defaults read -g com.apple.trackpad.acceleration 2>/dev/null || echo "DEFAULT")
MOUSE_ACCEL=$(defaults read -g com.apple.mouse.acceleration 2>/dev/null || echo "DEFAULT")

echo "Current trackpad scaling: $TRACKPAD_SCALING"
echo "Current mouse scaling: $MOUSE_SCALING"
echo "Current trackpad acceleration: $TRACKPAD_ACCEL"
echo "Current mouse acceleration: $MOUSE_ACCEL"
echo ""

# Check if any settings look problematic
NEEDS_FIXING=false

if [[ "$TRACKPAD_SCALING" != "DEFAULT" ]] && (($(echo "$TRACKPAD_SCALING < 0.3" | bc -l))); then
    echo "⚠️  Trackpad scaling looks too slow: $TRACKPAD_SCALING"
    NEEDS_FIXING=true
fi

if [[ "$MOUSE_SCALING" != "DEFAULT" ]] && (($(echo "$MOUSE_SCALING > 1000" | bc -l))); then
    echo "⚠️  Mouse scaling looks problematic: $MOUSE_SCALING"
    NEEDS_FIXING=true
fi

if [[ "$TRACKPAD_ACCEL" == "-1" ]] || [[ "$MOUSE_ACCEL" == "-1" ]]; then
    echo "⚠️  Acceleration is disabled (set to -1)"
    NEEDS_FIXING=true
fi

if [[ "$NEEDS_FIXING" == "false" ]]; then
    echo "✅ Your settings look normal - no recovery needed!"
    exit 0
fi

echo ""
echo "🔧 Problematic settings detected. Would you like to reset to defaults? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Recovery cancelled by user"
    exit 0
fi

echo ""
echo "🚑 Restoring default settings..."

# Remove problematic trackpad settings
if [[ "$TRACKPAD_SCALING" != "DEFAULT" ]]; then
    echo "   Removing trackpad scaling setting..."
    defaults delete -g com.apple.trackpad.scaling 2>/dev/null || true
fi

if [[ "$TRACKPAD_ACCEL" != "DEFAULT" ]]; then
    echo "   Removing trackpad acceleration setting..."
    defaults delete -g com.apple.trackpad.acceleration 2>/dev/null || true
fi

# Remove problematic mouse settings
if [[ "$MOUSE_SCALING" != "DEFAULT" ]]; then
    echo "   Removing mouse scaling setting..."
    defaults delete -g com.apple.mouse.scaling 2>/dev/null || true
fi

if [[ "$MOUSE_ACCEL" != "DEFAULT" ]]; then
    echo "   Removing mouse acceleration setting..."
    defaults delete -g com.apple.mouse.acceleration 2>/dev/null || true
fi

# Restart Dock to apply changes
echo "   Restarting Dock to apply changes..."
killall Dock 2>/dev/null || true

echo ""
echo "✅ Recovery complete!"
echo ""
echo "Your trackpad and mouse should now be back to normal macOS defaults."
echo "If you still have issues, try logging out and back in, or restarting your Mac."
echo ""
echo "The new version of Dragoboo uses safe event modification that won't"
echo "cause permanent system changes even if the app crashes."
