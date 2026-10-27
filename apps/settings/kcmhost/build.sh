#!/bin/sh
# Baut libkcmhost.so (wird bei der Installation einmal ausgeführt; braucht g++ und pkgconf).
set -e
cd "$(dirname "$0")"
MOC=$(pkg-config --variable=libexecdir Qt6Core 2>/dev/null)/moc
[ -x "$MOC" ] || MOC=/usr/lib/qt6/moc
"$MOC" kcmhost.h -o moc_kcmhost.cpp
KF=/usr/include/KF6
g++ -std=c++20 -O2 -shared -fPIC -o libkcmhost.so kcmhost.cpp moc_kcmhost.cpp \
    $(pkg-config --cflags --libs Qt6Core Qt6Gui Qt6Qml Qt6Quick) \
    -I$KF/KCMUtilsQuick -I$KF/KCMUtilsCore -I$KF/KCMUtils -I$KF/KCoreAddons \
    -lKF6KCMUtilsQuick -lKF6KCMUtilsCore -lKF6CoreAddons
rm -f moc_kcmhost.cpp
