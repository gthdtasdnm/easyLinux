#!/bin/sh
# Baut das Rechtsklick-Plugin für die Leiste (bei der Installation; braucht g++ und pkgconf).
set -e
cd "$(dirname "$0")"
MOC=$(pkg-config --variable=libexecdir Qt6Core 2>/dev/null)/moc
[ -x "$MOC" ] || MOC=/usr/lib/qt6/moc
QT="Qt6Core Qt6Gui Qt6Widgets Qt6DBus Qt6Qml Qt6Quick"
INC="-I. -I/usr/include/Plasma -I/usr/include/PlasmaQuick $(for d in /usr/include/KF6/*/; do printf -- '-I%s ' "$d"; done)"
# moc braucht die Include-Pfade, sonst findet es die Plugin-Metadaten (K_PLUGIN_CLASS_WITH_JSON) nicht
"$MOC" $INC $(pkg-config --cflags-only-I $QT) taskbarmenu.cpp -o taskbarmenu.moc
g++ -std=c++20 -O2 -shared -fPIC -o org.easylinux.taskbarmenu.so taskbarmenu.cpp $INC \
    $(pkg-config --cflags --libs $QT) -lPlasma -lPlasmaQuick -lKF6KIOGui -lKF6KIOCore -lKF6CoreAddons -lKF6ConfigCore
rm -f taskbarmenu.moc
