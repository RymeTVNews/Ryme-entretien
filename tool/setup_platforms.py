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

# Desugaring Java 8+ requis par flutter_local_notifications.
kts = ROOT / "android/app/build.gradle.kts"
groovy = ROOT / "android/app/build.gradle"
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = g.replace("compileOptions {",
                      "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "coreLibraryDesugaring(" not in g:
        g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(g, encoding="utf-8")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "coreLibraryDesugaringEnabled" not in g:
        g = g.replace("compileOptions {",
                      "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    if "coreLibraryDesugaring '" not in g:
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(g, encoding="utf-8")
else:
    print("AVERTISSEMENT : build.gradle introuvable (Android).", file=sys.stderr)

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
