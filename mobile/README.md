# Chat App — Mobil İstemci

Flutter ile geliştirilen mobil uygulama. Kurulum, çalıştırma ve mimari açıklamaları
projenin kök dizinindeki [README](../README.md) dosyasındadır.

## Hızlı başlangıç

```bash
flutter pub get
flutter run
```

**Sunucu adresi derleme anında gömülür.** Varsayılan değer Android emülatörü içindir
(`10.0.2.2:5000`). Gerçek bir cihazda çalıştırırken bilgisayarınızın yerel ağ adresini
vermeniz gerekir:

```bash
flutter run \
  --dart-define=API_URL=http://192.168.1.20:5000/api/v1 \
  --dart-define=SOCKET_URL=http://192.168.1.20:5000
```

## Testler

```bash
flutter test
```

## Klasör düzeni

```
lib/
├── core/           yapılandırma, ağ katmanı, güvenli depolama, tema, yardımcılar
├── data/           modeller, veri kaynakları (API + socket), repository'ler
└── presentation/   ekranlar, paylaşılan widget'lar, Riverpod provider'ları
```

Mimari kararların gerekçeleri için:
[Frontend mimarisi](../README.md#frontend-mimarisi) ve [DECISIONS.md](../DECISIONS.md).
