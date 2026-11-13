#!/usr/bin/env python3
"""Génère les dossiers android/ et ios/ (flutter create) puis applique les
réglages nécessaires aux notifications locales programmées.

Usage (depuis la racine du projet) :  python3 tool/setup_platforms.py
Idempotent : peut être relancé sans danger.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_NAME = "Ryme entretien"

if not (ROOT / "android").exists() or not (ROOT / "ios").exists():
    subprocess.check_call(
        ["flutter", "create", "--org", "com.ryme",
         "--project-name", "ryme_entretien",
         "--platforms=android,ios", "."],
        cwd=ROOT,
    )

# Le test d'exemple généré par flutter create référence « MyApp » : on le retire.
sample_test = ROOT / "test/widget_test.dart"
if sample_test.exists():
    sample_test.unlink()

# ---------------------------------------------------------------- Android --
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")

perms = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
]
for p in perms:
    if p not in m:
        m = m.replace("<application",
                      f'<uses-permission android:name="{p}"/>\n    <application', 1)

if "ScheduledNotificationReceiver" not in m:
    receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    """
    m = m.replace("</application>", receivers + "</application>", 1)

m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', m, count=1)
manifest.write_text(m, encoding="utf-8")

# Desugaring Java 8+ (flutter_local_notifications), minSdk 23 (Firebase) et
# signature de production (android/key.properties, créé par la CI ou à la main).
kts = ROOT / "android/app/build.gradle.kts"
groovy = ROOT / "android/app/build.gradle"
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = g.replace("compileOptions {",
                      "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "coreLibraryDesugaring(" not in g:
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    g = re.sub(r"minSdk(Version)?\s*=\s*flutter\.minSdkVersion",
               "minSdk = maxOf(flutter.minSdkVersion, 23)", g, count=1)
    if "keystoreProperties" not in g:
        g = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + g
        g = g.replace("android {", """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
""", 1)
        g = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                   'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
                   g, count=1)
    kts.write_text(g, encoding="utf-8")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "coreLibraryDesugaringEnabled" not in g:
        g = g.replace("compileOptions {",
                      "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    if "coreLibraryDesugaring '" not in g:
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion",
               "minSdkVersion Math.max(flutter.minSdkVersion, 23)", g, count=1)
    if "keystoreProperties" not in g:
        g = g.replace("android {", """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
""", 1)
        g = re.sub(r"signingConfig\s+signingConfigs\.(debug|getByName\('debug'\))",
                   "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug",
                   g, count=1)
    groovy.write_text(g, encoding="utf-8")
else:
    print("AVERTISSEMENT : build.gradle introuvable (Android).", file=sys.stderr)

# Le contrôle « lintVital » des modules de plugins plante (erreur interne de
# l'outil lint, NoSuchMethodError) avec certaines combinaisons de versions :
# on le désactive pour les compilations release.
root_kts = ROOT / "android/build.gradle.kts"
root_groovy = ROOT / "android/build.gradle"
if root_kts.exists():
    g = root_kts.read_text(encoding="utf-8")
    if "lintVital" not in g:
        g += """
subprojects {
    tasks.configureEach {
        if (name.startsWith("lintVital")) {
            enabled = false
        }
    }
}
"""
        root_kts.write_text(g, encoding="utf-8")
elif root_groovy.exists():
    g = root_groovy.read_text(encoding="utf-8")
    if "lintVital" not in g:
        g += """
subprojects {
    tasks.configureEach { task ->
        if (task.name.startsWith("lintVital")) {
            task.enabled = false
        }
    }
}
"""
        root_groovy.write_text(g, encoding="utf-8")

# -------------------------------------------------------------------- iOS --
delegate = ROOT / "ios/Runner/AppDelegate.swift"
if delegate.exists():
    d = delegate.read_text(encoding="utf-8")
    if "UNUserNotificationCenter" not in d and "GeneratedPluginRegistrant.register(with: self)" in d:
        d = d.replace(
            "GeneratedPluginRegistrant.register(with: self)",
            "if #available(iOS 10.0, *) {\n"
            "      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate\n"
            "    }\n"
            "    GeneratedPluginRegistrant.register(with: self)",
            1,
        )
        delegate.write_text(d, encoding="utf-8")
    elif "UNUserNotificationCenter" not in d:
        print("AVERTISSEMENT : AppDelegate.swift a une structure inattendue ; "
              "ajoutez le délégué UNUserNotificationCenter manuellement "
              "(voir README).", file=sys.stderr)

plist = ROOT / "ios/Runner/Info.plist"
if plist.exists():
    p = plist.read_text(encoding="utf-8")
    p = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
               rf"\g<1>{APP_NAME}\g<2>", p, count=1)
    plist.write_text(p, encoding="utf-8")

print("Plateformes configurées.")
