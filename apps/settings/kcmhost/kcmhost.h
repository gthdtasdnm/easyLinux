// Brücke zwischen der Einstellungen-App (Python/QML) und den KDE-Einstellungsseiten (KCMs):
// lädt eine QML-KCM in die QML-Engine der App, damit sie im selben Fenster erscheint.
#pragma once

#include <QObject>
#include <QString>

class KcmHost : public QObject
{
    Q_OBJECT
public:
    explicit KcmHost(QObject *parent = nullptr);

    // Lädt die KCM (z. B. "kcm_kscreen"). Gibt das Modul (KQuickConfigModule) zurück –
    // oder null, wenn es keine QML-KCM ist (dann muss sie in einem eigenen Fenster öffnen).
    Q_INVOKABLE QObject *load(const QString &name);
    Q_INVOKABLE void unload(QObject *module);
    Q_INVOKABLE bool embeddable(const QString &name) const;
};
