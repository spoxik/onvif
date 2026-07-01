# ONVIF Scanner

Flutterowa aplikacja na Androida do audytu własnych sieci CCTV.

## Funkcje

- skanowanie podsieci LAN/VPN, np. `10.10.0.0/24` albo `192.168.1.0/24`,
- sprawdzanie portów typowych dla kamer/NVR: `80`, `8080`, `8000`, `8899`, `554`,
- podstawowe wykrywanie ONVIF przez `GetDeviceInformation`,
- odczyt producenta, modelu, firmware i numeru seryjnego, jeśli urządzenie udostępnia te dane,
- osobna zakładka Shodan z własnym kluczem API użytkownika,
- eksport wyników do CSV,
- interfejs po polsku.

## Ważne

Używaj aplikacji tylko w sieciach i wobec urządzeń, do których masz uprawnienia. Moduł Shodan jest przeznaczony do audytu własnych/autoryzowanych zasobów oraz inwentaryzacji wyników z własnego konta API.

## Uruchomienie

Jeżeli repozytorium nie ma jeszcze katalogów `android/`, `ios/`, `web/`, utwórz je lokalnie poleceniem:

```bash
flutter create --platforms=android .
flutter pub get
flutter run
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
  services/
  screens/
  widgets/
```

## Co dalej

Planowane kolejne moduły:

- zapis historii skanowań,
- podgląd RTSP,
- PTZ ONVIF,
- eksport XLSX,
- filtrowanie Dahua/Hikvision/Uniview,
- bezpieczne przechowywanie klucza API Shodan.
