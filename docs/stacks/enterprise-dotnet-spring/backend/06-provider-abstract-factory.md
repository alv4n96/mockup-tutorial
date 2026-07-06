# Backend 06 - Provider Dengan Abstract Factory

## Yang Dibuat

Factory untuk keluarga provider email, payment, storage, atau notification.

## Referensi

https://refactoring.guru/design-patterns/abstract-factory

## Alur

1. Buat interface product, misalnya `EmailSender`, `TemplateRenderer`, `DeliveryTracker`.
2. Buat interface factory, misalnya `NotificationProviderFactory`.
3. Buat concrete factory untuk provider production.
4. Buat fake factory untuk test.
5. Daftarkan factory di dependency injection.
6. Pakai factory di application service.

## Output

Provider bisa diganti tanpa mengubah use case enterprise.
