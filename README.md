# ONVIF Scanner

Flutterowa aplikacja na Androida do audytu własnych sieci CCTV, ONVIF, RTSP oraz wyników z Shodan.

## Zakładki

### LAN

- skanowanie podsieci LAN/VPN, np. `10.10.0.0/24` albo `192.168.1.0/24`,
- sprawdzanie portów typowych dla kamer/NVR: `80`, `8080`, `8000`, `8899`, `554`,
- podstawowe wykrywanie ONVIF przez `GetDeviceInformation`,
- odczyt producenta, modelu, firmware i numeru seryjnego, jeśli urządzenie udostępnia dane.

### Kamery

- widok urządzeń rozpoznanych jako ONVIF/RTSP,
- szybkie dodawanie RTSP,
- notatki do urządzeń,
- etykiety, np. `Dahua`, `magazyn`, `klient A`,
- dodawanie do ulubionych.

### Shodan

- wyszukiwanie przez własny klucz API Shodan,
- zapis lokalny klucza API, opcjonalny,
- zapisane zapytania Shodan,
- import przykładowych zapytań,
- eksport zapytań do JSON,
- mapa lokalizacji hostów, jeśli Shodan zwróci współrzędne.

### Ulubione

- lokalna lista zapisanych urządzeń,
- notatki, etykiety i RTSP przypisane do urządzenia,
- szybki powrót do często używanych kamer/NVR.

### Ustawienia

- przełącznik zapisu klucza Shodan,
- licznik ulubionych urządzeń,
- licznik zapisanych zapytań Shodan,
- przypomnienie o legalnym użyciu.

## Eksport i raporty

- eksport aktualnie filtrowanych wyników do CSV,
- generowanie raportu PDF z wyników,
- filtrowanie po IP, producencie, modelu, numerze seryjnym, etykiecie i notatce.

## Ważne

Używaj aplikacji tylko w sieciach i wobec urządzeń, do których masz uprawnienia. Moduł Shodan jest przeznaczony do audytu własnych/autoryzowanych zasobów oraz inwentaryzacji wyników z własnego konta API.

## Uruchomienie

Jeżeli repozytorium nie ma jeszcze katalogów `android/`, `ios/`, `web/`, utwórz je lokalnie poleceniem:

```bash
flutter create --platforms=android .
flutter pub get
flutter run
```

Po aktualizacji zależności uruchom:

```bash
flutter clean
flutter pub get
```

Do zbudowania APK:

```bash
flutter build apk --release
```

Gotowy plik znajdziesz zwykle tutaj:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Struktura

```text
lib/
  main.dart
  models/
    device_result.dart
    shodan_query.dart
  services/
    export_service.dart
    lan_scanner_service.dart
    onvif_service.dart
    report_service.dart
    shodan_service.dart
    storage_service.dart
  widgets/
    device_result_tile.dart
```

## Kolejne sensowne kroki

- prawdziwy podgląd RTSP w aplikacji,
- PTZ ONVIF,
- logowanie ONVIF WS-Security,
- eksport XLSX,
- historia skanowań,
- filtrowanie Dahua/Hikvision/Uniview osobnymi przełącznikami.
