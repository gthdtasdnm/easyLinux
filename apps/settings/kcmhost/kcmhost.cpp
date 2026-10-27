#include "kcmhost.h"

#include <KPluginMetaData>
#include <KQuickConfigModule>
#include <KQuickConfigModuleLoader>
#include <QQmlEngine>
#include <QtQml>

// QML-KCMs liegen in diesen Plugin-Ordnern; QWidget-KCMs (systemsettings_qwidgets) lassen sich nicht einbetten
static const QStringList KCM_DIRS = {QStringLiteral("plasma/kcms/systemsettings"), QStringLiteral("plasma/kcms"),
                                     QStringLiteral("plasma/kcms/kinfocenter")};

static KPluginMetaData findKcm(const QString &name)
{
    for (const QString &dir : KCM_DIRS) {
        const KPluginMetaData meta = KPluginMetaData::findPluginById(dir, name);
        if (meta.isValid()) {
            return meta;
        }
    }
    return {};
}

KcmHost::KcmHost(QObject *parent)
    : QObject(parent)
{
}

bool KcmHost::embeddable(const QString &name) const
{
    return findKcm(name).isValid();
}

QObject *KcmHost::load(const QString &name)
{
    const KPluginMetaData meta = findKcm(name);
    QQmlEngine *engine = qmlEngine(this);
    if (!meta.isValid() || !engine) {
        return nullptr;
    }
    // Die Engine gehört der App – nicht freigeben, wenn das Modul sie loslässt
    const std::shared_ptr<QQmlEngine> shared(engine, [](QQmlEngine *) {});
    const auto result = KQuickConfigModuleLoader::loadModule(meta, nullptr, {}, shared);
    if (!result) {
        qWarning() << "KCM konnte nicht geladen werden:" << name << result.errorString;
        return nullptr;
    }
    KQuickConfigModule *module = result.plugin;
    QQmlEngine::setObjectOwnership(module, QQmlEngine::CppOwnership);
    module->load();
    if (!module->mainUi()) {
        delete module;
        return nullptr;
    }
    return module;
}

void KcmHost::unload(QObject *module)
{
    if (module) {
        module->deleteLater();
    }
}

// Aufruf aus Python (ctypes), bevor die QML-Oberfläche geladen wird
extern "C" Q_DECL_EXPORT void easylinux_register_kcmhost()
{
    qmlRegisterType<KcmHost>("org.easylinux.kcmhost", 1, 0, "KcmHost");
}
