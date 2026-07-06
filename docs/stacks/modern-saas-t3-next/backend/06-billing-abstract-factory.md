# Backend 06 - Billing Dengan Abstract Factory

## Yang Dibuat

Module `billing` dengan provider abstraction untuk checkout dan webhook.

## Referensi Pattern

Abstract Factory dari Refactoring Guru: https://refactoring.guru/design-patterns/abstract-factory

## Alur

1. Buat interface `CheckoutGateway`.
2. Buat interface `WebhookVerifier`.
3. Buat interface `BillingProviderFactory`.
4. Buat `StripeBillingFactory`.
5. Buat `FakeBillingFactory` untuk test.
6. Pilih factory dari env.
7. Inject factory ke `CreateCheckout`.
8. Pakai verifier di webhook handler.

## Kenapa Penting

Application layer tidak bergantung langsung pada Stripe, Midtrans, atau provider lain. Satu keluarga object provider dibuat konsisten oleh factory yang sama.

## Output

Billing bisa diganti provider tanpa mengubah use case utama.
