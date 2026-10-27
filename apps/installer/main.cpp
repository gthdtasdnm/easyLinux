// easyLinux-Installer: herunterladen, doppelklicken, „Installieren“ – kein Terminal.
// Eine einzige Datei: Oberfläche (Main.qml) und Root-Skripte sind eingebaut (Qt-Ressourcen).
// Nach der Installation liegt er auch unter /opt/easylinux (Einstellungen → System → easyLinux) zum Entfernen.
// Die Arbeit mit Administratorrechten machen install-root.sh / remove-root.sh (über pkexec).
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QStandardPaths>

static const QString USER_SETUP = QStringLiteral("/opt/easylinux/bin/easylinux-user-setup");

class Backend : public QObject
{
    Q_OBJECT
    // checking | notInstalled | installed | working | installedDone | removedDone | error
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString step READ step NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString log READ log NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit Backend(QObject *parent = nullptr)
        : QObject(parent)
    {
        refresh();
    }

    QString state() const { return m_state; }
    QString step() const { return m_step; }
    double progress() const { return m_progress; }
    QString log() const { return m_log; }
    QString error() const { return m_error; }

    Q_INVOKABLE void refresh()
    {
        const int rc = QProcess::execute(QStringLiteral("pacman"), {QStringLiteral("-Qq"), QStringLiteral("easylinux")});
        setState(rc == 0 ? QStringLiteral("installed") : QStringLiteral("notInstalled"));
    }

    Q_INVOKABLE void install()
    {
        begin(QStringLiteral("Passwort wird abgefragt …"));
        runRoot(QStringLiteral("install-root.sh"), {}, [this] {
            // Leiste, Tastenkürzel usw. für den angemeldeten Benutzer gleich einrichten
            setStep(QStringLiteral("Wird für Sie eingerichtet …"), -1);
            auto *setup = new QProcess(this);
            connect(setup, &QProcess::finished, this, [this, setup] {
                setup->deleteLater();
                setState(QStringLiteral("installedDone"));
            });
            setup->start(USER_SETUP, {QStringLiteral("--force")});
        });
    }

    Q_INVOKABLE void remove()
    {
        begin(QStringLiteral("Ihre Einstellungen werden wiederhergestellt …"));
        auto *undo = new QProcess(this);
        connect(undo, &QProcess::finished, this, [this, undo] {
            undo->deleteLater();
            setStep(QStringLiteral("Passwort wird abgefragt …"), -1);
            runRoot(QStringLiteral("remove-root.sh"), {QDir::homePath()}, [this] { setState(QStringLiteral("removedDone")); });
        });
        if (QFile::exists(USER_SETUP)) {
            undo->start(USER_SETUP, {QStringLiteral("--remove")});
        } else {
            undo->start(QStringLiteral("true"), {});
        }
    }

    Q_INVOKABLE void logout()
    {
        QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(
            QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"), QStringLiteral("logout")));
    }

Q_SIGNALS:
    void changed();

private:
    void setState(const QString &s) { m_state = s; Q_EMIT changed(); }
    void setStep(const QString &s, double p) { m_step = s; m_progress = p; Q_EMIT changed(); }

    void begin(const QString &step)
    {
        m_log.clear();
        m_error.clear();
        m_state = QStringLiteral("working");
        setStep(step, -1);
    }

    void appendLog(const QString &text)
    {
        m_log += text;
        if (m_log.size() > 60000) {
            m_log = m_log.right(50000);
        }
    }

    // Skript mit Administratorrechten ausführen; Fortschritt aus „@@STEP“ und pacmans „(3/12)“ lesen
    void runRoot(const QString &script, const QStringList &args, std::function<void()> onSuccess)
    {
        auto *proc = new QProcess(this);
        proc->setProcessChannelMode(QProcess::MergedChannels);
        connect(proc, &QProcess::readyRead, this, [this, proc] {
            static const QRegularExpression count(QStringLiteral("^\\(\\s*(\\d+)/(\\d+)\\)\\s+(\\S+)"));
            while (proc->canReadLine()) {
                const QString line = QString::fromUtf8(proc->readLine()).trimmed();
                if (line.startsWith(QLatin1String("@@STEP "))) {
                    setStep(line.mid(7) + QStringLiteral(" …"), -1);
                } else if (line == QLatin1String("@@DONE")) {
                    continue;
                } else {
                    appendLog(line + QLatin1Char('\n'));
                    const auto m = count.match(line);
                    if (m.hasMatch()) {
                        const double i = m.captured(1).toDouble(), n = m.captured(2).toDouble();
                        const QString what = m.captured(3);
                        // pacman zählt zweimal: erst Prüfen/Herunterladen, dann Installieren
                        const bool installing = line.contains(QLatin1String("installing")) || line.contains(QLatin1String("upgrading"))
                            || line.contains(QLatin1String("removing"));
                        setStep(installing ? QStringLiteral("Wird installiert (%1 von %2) …").arg(i).arg(n)
                                           : QStringLiteral("Wird vorbereitet (%1 von %2) …").arg(i).arg(n),
                                installing ? i / n : -1);
                        Q_UNUSED(what)
                    } else if (line.startsWith(QLatin1String(":: Retrieving")) || line.contains(QLatin1String("downloading"))) {
                        setStep(QStringLiteral("Wird heruntergeladen …"), -1);
                    } else {
                        Q_EMIT changed();  // Protokoll aktualisieren
                    }
                }
            }
        });
        connect(proc, &QProcess::finished, this, [this, proc, onSuccess](int code, QProcess::ExitStatus status) {
            proc->deleteLater();
            appendLog(QString::fromUtf8(proc->readAll()));
            if (status == QProcess::NormalExit && code == 0) {
                onSuccess();
            } else if (code == 126 || code == 127) {
                m_error = QStringLiteral("Die Passwortabfrage wurde abgebrochen.");
                refresh();
                Q_EMIT changed();
            } else {
                m_error = QStringLiteral("Das hat leider nicht geklappt. Besteht eine Internetverbindung? Details stehen unten.");
                setState(QStringLiteral("error"));
            }
        });
        // Skript aus den eingebauten Ressourcen direkt an bash übergeben (keine Datei, die jemand ändern könnte)
        QFile file(QStringLiteral(":/") + script);
        if (!file.open(QIODevice::ReadOnly)) {
            m_error = QStringLiteral("Interner Fehler: Skript fehlt.");
            setState(QStringLiteral("error"));
            return;
        }
        QStringList all{QStringLiteral("/bin/bash"), QStringLiteral("-c"), QString::fromUtf8(file.readAll()), script};
        all += args;
        proc->start(QStringLiteral("pkexec"), all);
    }

    QString m_state = QStringLiteral("checking");
    QString m_step;
    double m_progress = -1;
    QString m_log;
    QString m_error;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", qgetenv("QT_QUICK_CONTROLS_STYLE").isEmpty() ? "org.kde.desktop" : qgetenv("QT_QUICK_CONTROLS_STYLE"));
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("easyLinux"));
    app.setDesktopFileName(QStringLiteral("easylinux-installer"));
    app.setWindowIcon(QIcon(QStringLiteral(":/easylinux.svg")));

    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("startRemove"), app.arguments().contains(QStringLiteral("--remove")));
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}

#include "main.moc"
