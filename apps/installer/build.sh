#!/bin/sh
# Baut den easyLinux-Installer als einzelne Datei (Oberfläche und Skripte eingebaut; braucht g++ und pkgconf).
set -e
cd "$(dirname "$0")"
BIN=$(pkg-config --variable=libexecdir Qt6Core 2>/dev/null)
[ -x "$BIN/moc" ] || BIN=/usr/lib/qt6
QT="Qt6Core Qt6Gui Qt6Qml Qt6Quick Qt6DBus"
"$BIN/moc" $(pkg-config --cflags-only-I $QT) main.cpp -o main.moc
"$BIN/rcc" installer.qrc -o qrc_installer.cpp
g++ -std=c++20 -O2 -fPIC -o easylinux-installer main.cpp qrc_installer.cpp -I. $(pkg-config --cflags --libs $QT)
strip easylinux-installer
rm -f main.moc qrc_installer.cpp
