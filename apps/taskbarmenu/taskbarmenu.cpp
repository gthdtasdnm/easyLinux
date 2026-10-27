// Rechtsklickmenü der Leiste wie bei Windows (ersetzt das Plasma-Plugin „org.kde.contextmenu“ für Leisten):
//  - Rechtsklick auf den Startknopf: Menü wie Win+X (Terminal, Task-Manager, Einstellungen, Herunterfahren …)
//  - Rechtsklick sonst auf der Leiste: Task-Manager und Taskleisteneinstellungen
#include <KIO/CommandLauncherJob>
#include <KPluginFactory>
#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/ContainmentActions>
#include <Plasma/Corona>
#include <PlasmaQuick/AppletQuickItem>
#include <QAction>
#include <QCursor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QMenu>
#include <QStandardPaths>

static const QString SETTINGS = QStringLiteral("/opt/easylinux/bin/easylinux-settings");

class TaskbarMenu : public Plasma::ContainmentActions
{
    Q_OBJECT
public:
    TaskbarMenu(QObject *parent, const QVariantList &)
        : Plasma::ContainmentActions(parent)
    {
    }

    QList<QAction *> contextualActions() override
    {
        qDeleteAll(m_owned);  // eigene Einträge der letzten Anzeige
        m_owned.clear();
        m_actions.clear();
        const QString applet = appletUnderCursor();
        if (applet.contains(QLatin1String("kickoff")) || applet.contains(QLatin1String("kicker"))) {
            startMenu();
        } else {
            taskbarMenu();
        }
        return m_actions;
    }

private:
    QList<QAction *> m_actions;  // angezeigte Einträge
    QList<QAction *> m_owned;    // davon selbst erzeugt (Plasma-eigene Einträge gehören der Leiste)

    // Plugin-ID des Miniprogramms unter dem Mauszeiger (z. B. org.kde.plasma.kickoff)
    QString appletUnderCursor()
    {
        const QPointF cursor = QCursor::pos();
        for (Plasma::Applet *applet : containment()->applets()) {
            if (!PlasmaQuick::AppletQuickItem::hasItemForApplet(applet)) {
                continue;
            }
            QQuickItem *item = PlasmaQuick::AppletQuickItem::itemForApplet(applet);
            const QRectF rect(item->mapToGlobal(QPointF(0, 0)), QSizeF(item->width(), item->height()));
            if (rect.contains(cursor)) {
                return applet->pluginMetaData().pluginId();
            }
        }
        return {};
    }

    static bool installed(const QString &desktopId)
    {
        return !QStandardPaths::locate(QStandardPaths::ApplicationsLocation, desktopId + QLatin1String(".desktop")).isEmpty();
    }

    static void launch(const QString &cmd, const QStringList &args, const QString &desktopName = {})
    {
        auto *job = new KIO::CommandLauncherJob(cmd, args);
        if (!desktopName.isEmpty()) {
            job->setDesktopName(desktopName);
        }
        job->start();
    }

    static void dbus(bool system, const QString &service, const QString &path, const QString &iface, const QString &method,
                     const QVariantList &args = {})
    {
        QDBusMessage msg = QDBusMessage::createMethodCall(service, path, iface, method);
        msg.setArguments(args);
        (system ? QDBusConnection::systemBus() : QDBusConnection::sessionBus()).asyncCall(msg);
    }

    QAction *add(const QString &icon, const QString &text, std::function<void()> fn, QMenu *menu = nullptr)
    {
        auto *action = new QAction(QIcon::fromTheme(icon), text, menu ? static_cast<QObject *>(menu) : this);
        connect(action, &QAction::triggered, this, fn);
        if (menu) {
            menu->addAction(action);
        } else {
            m_actions.append(action);
            m_owned.append(action);
        }
        return action;
    }

    void separator()
    {
        auto *sep = new QAction(this);
        sep->setSeparator(true);
        m_actions.append(sep);
        m_owned.append(sep);
    }

    void startMenu()
    {
        add(QStringLiteral("preferences-desktop-apps"), QStringLiteral("Installierte Apps"), [] {
            launch(SETTINGS, {QStringLiteral("installed")}, QStringLiteral("easylinux-settings"));
        });
        add(QStringLiteral("preferences-system-power-management"), QStringLiteral("Energieoptionen"), [] {
            launch(SETTINGS, {QStringLiteral("kcm_powerdevilprofilesconfig")}, QStringLiteral("easylinux-settings"));
        });
        add(QStringLiteral("computer"), QStringLiteral("System"), [] {
            launch(SETTINGS, {QStringLiteral("kcm_about-distro")}, QStringLiteral("easylinux-settings"));
        });
        if (installed(QStringLiteral("org.kde.kinfocenter"))) {
            add(QStringLiteral("hwinfo"), QStringLiteral("Geräte-Manager"), [] {
                launch(QStringLiteral("kinfocenter"), {}, QStringLiteral("org.kde.kinfocenter"));
            });
        }
        add(QStringLiteral("network-wired"), QStringLiteral("Netzwerkverbindungen"), [] {
            launch(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_networkmanagement")});
        });
        if (installed(QStringLiteral("org.kde.partitionmanager"))) {
            add(QStringLiteral("partitionmanager"), QStringLiteral("Datenträgerverwaltung"), [] {
                launch(QStringLiteral("partitionmanager"), {}, QStringLiteral("org.kde.partitionmanager"));
            });
        }
        separator();
        add(QStringLiteral("utilities-terminal"), QStringLiteral("Terminal"), [] {
            launch(QStringLiteral("konsole"), {}, QStringLiteral("org.kde.konsole"));
        });
        add(QStringLiteral("utilities-terminal-root"), QStringLiteral("Terminal (Administrator)"), [] {
            // run0 fragt grafisch nach dem Passwort – wie die Benutzerkontensteuerung bei Windows
            const bool run0 = !QStandardPaths::findExecutable(QStringLiteral("run0")).isEmpty();
            launch(QStringLiteral("konsole"), {QStringLiteral("-e"), run0 ? QStringLiteral("run0") : QStringLiteral("sudo -i")},
                   QStringLiteral("org.kde.konsole"));
        });
        add(QStringLiteral("utilities-system-monitor"), QStringLiteral("Task-Manager"), [] {
            launch(QStringLiteral("/opt/easylinux/bin/easylinux-taskmanager"), {}, QStringLiteral("easylinux-taskmanager"));
        });
        add(QStringLiteral("preferences-system"), QStringLiteral("Einstellungen"), [] {
            launch(SETTINGS, {}, QStringLiteral("easylinux-settings"));
        });
        add(QStringLiteral("system-file-manager"), QStringLiteral("Datei-Explorer"), [] {
            launch(QStringLiteral("dolphin"), {}, QStringLiteral("org.kde.dolphin"));
        });
        add(QStringLiteral("search"), QStringLiteral("Suchen"), [] {
            dbus(false, QStringLiteral("org.kde.krunner"), QStringLiteral("/App"), QStringLiteral("org.kde.krunner.App"),
                 QStringLiteral("display"));
        });
        add(QStringLiteral("system-run"), QStringLiteral("Ausführen"), [] {
            dbus(false, QStringLiteral("org.kde.krunner"), QStringLiteral("/App"), QStringLiteral("org.kde.krunner.App"),
                 QStringLiteral("display"));
        });
        separator();
        auto *power = new QMenu();
        add(QStringLiteral("system-lock-screen"), QStringLiteral("Sperren"), [] {
            dbus(false, QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                 QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("Lock"));
        }, power);
        add(QStringLiteral("system-log-out"), QStringLiteral("Abmelden"), [] {
            dbus(false, QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"),
                 QStringLiteral("logout"));
        }, power);
        add(QStringLiteral("system-suspend"), QStringLiteral("Energie sparen"), [] {
            dbus(true, QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
                 QStringLiteral("org.freedesktop.login1.Manager"), QStringLiteral("Suspend"), {true});
        }, power);
        add(QStringLiteral("system-reboot"), QStringLiteral("Neu starten"), [] {
            dbus(false, QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"),
                 QStringLiteral("logoutAndReboot"));
        }, power);
        add(QStringLiteral("system-shutdown"), QStringLiteral("Herunterfahren"), [] {
            dbus(false, QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"),
                 QStringLiteral("logoutAndShutdown"));
        }, power);
        auto *powerAction = new QAction(QIcon::fromTheme(QStringLiteral("system-shutdown")),
                                        QStringLiteral("Herunterfahren oder abmelden"), this);
        powerAction->setMenu(power);
        connect(powerAction, &QObject::destroyed, power, &QObject::deleteLater);
        m_actions.append(powerAction);
        m_owned.append(powerAction);
        add(QStringLiteral("user-desktop"), QStringLiteral("Desktop"), [] {
            dbus(false, QStringLiteral("org.kde.kglobalaccel"), QStringLiteral("/component/kwin"),
                 QStringLiteral("org.kde.kglobalaccel.Component"), QStringLiteral("invokeShortcut"),
                 {QStringLiteral("Show Desktop")});
        });
    }

    void taskbarMenu()
    {
        add(QStringLiteral("utilities-system-monitor"), QStringLiteral("Task-Manager"), [] {
            launch(QStringLiteral("/opt/easylinux/bin/easylinux-taskmanager"), {}, QStringLiteral("easylinux-taskmanager"));
        });
        Plasma::Containment *c = containment();
        add(QStringLiteral("configure"), QStringLiteral("Taskleisteneinstellungen"), [c] {
            if (QAction *configure = c->internalAction(QStringLiteral("configure"))) {
                configure->trigger();  // Leiste bearbeiten (Größe, Position, Elemente)
            } else if (c->corona()) {
                c->corona()->setEditMode(true);
            }
        });
        // „Miniprogramme hinzufügen“ von Plasma behalten
        if (QAction *widgets = c->internalAction(QStringLiteral("add widgets"))) {
            separator();
            m_actions.append(widgets);
        }
    }
};

K_PLUGIN_CLASS_WITH_JSON(TaskbarMenu, "metadata.json")

#include "taskbarmenu.moc"
