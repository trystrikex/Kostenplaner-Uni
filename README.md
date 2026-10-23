# Kostenplaner für Uni

Native SwiftUI-App für iOS 17+, um während der Uni Einnahmen, Ausgaben, Budgets und einfache Freundes-Schulden zu planen.

## Features

- Übersicht mit Monatsbilanz, verbleibendem Budget, Einnahmen und offenen Schulden
- Schnelle Erfassung von Ausgaben, Einnahmen, Budgets und Schulden
- Belegfoto oder Screenshot an Ausgaben anhängen und Betrag lokal per Apple Vision erkennen
- Fixkosten und monatliche Wiederholungen als Eigenschaften von Buchungen
- Deutsche UI, Euro-Beträge und Cent-genaue Speicherung
- Supabase-ready: Auth per E-Mail OTP, Cloud-Sync, private Belegablage und RLS-SQL-Schema

## Supabase einrichten

1. Neues Supabase-Projekt erstellen.
2. `Supabase/schema.sql` im Supabase SQL Editor ausführen.
3. In `Kostenplaner/Services/SupabaseConfig.swift` `projectURL` und `publishableKey` eintragen.
4. In Supabase unter **Authentication → URL Configuration → Redirect URLs** diese URL erlauben: `kostenplaner://login-callback`.
5. In Xcode das Package `https://github.com/supabase/supabase-swift` auflösen lassen.

Ohne Supabase-Konfiguration startet die App im Demo-Modus mit lokalen Beispieldaten. OCR für Belege läuft kostenlos lokal auf dem iPhone; Supabase Storage wird nur für das dauerhafte Speichern und Synchronisieren der Belegbilder genutzt.

## Projekt öffnen

Öffne `Kostenplaner.xcodeproj` in Xcode und starte das Scheme `Kostenplaner` auf einem iOS-17+-Simulator.
