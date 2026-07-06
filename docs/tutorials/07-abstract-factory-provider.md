# 07 - Abstract Factory Untuk Provider Dan Variasi Fitur

## Referensi

Materi ini memakai konsep dari Refactoring Guru: [Abstract Factory](https://refactoring.guru/design-patterns/abstract-factory). Intinya, Abstract Factory membuat keluarga object yang saling terkait tanpa membuat client code bergantung pada concrete class.

## Kenapa Dipakai Di SaaS

SaaS sering punya provider yang bisa berbeda antar environment, tenant, atau paket:

- Email: Resend, SendGrid, SES.
- Payment: Stripe, Midtrans, Xendit.
- Storage: S3, Cloudflare R2, Azure Blob.
- Search: PostgreSQL full-text, Meilisearch, Elasticsearch.
- Notification: email, in-app, webhook.

Tanpa factory, use case akan penuh conditional:

```text
if provider == stripe
if provider == midtrans
if provider == sendgrid
```

Itu membuat application layer sulit dites dan sulit dikembangkan.

## Bentuk Product Family

Contoh keluarga provider billing:

```text
BillingProviderFactory
  createCheckoutGateway()
  createWebhookVerifier()
  createInvoiceReader()

StripeBillingProviderFactory
  StripeCheckoutGateway
  StripeWebhookVerifier
  StripeInvoiceReader

MidtransBillingProviderFactory
  MidtransCheckoutGateway
  MidtransWebhookVerifier
  MidtransInvoiceReader
```

Semua object dalam satu factory harus cocok satu sama lain. Jangan memakai Stripe checkout dengan Midtrans webhook verifier.

## TypeScript Example

```ts
export interface CheckoutGateway {
  createCheckout(input: CheckoutInput): Promise<CheckoutSession>;
}

export interface WebhookVerifier {
  verify(payload: string, signature: string): Promise<PaymentEvent>;
}

export interface BillingProviderFactory {
  createCheckoutGateway(): CheckoutGateway;
  createWebhookVerifier(): WebhookVerifier;
}

export class StripeBillingFactory implements BillingProviderFactory {
  createCheckoutGateway(): CheckoutGateway {
    return new StripeCheckoutGateway();
  }

  createWebhookVerifier(): WebhookVerifier {
    return new StripeWebhookVerifier();
  }
}
```

Use case:

```ts
export class CreateCheckoutUseCase {
  constructor(private readonly billingFactory: BillingProviderFactory) {}

  async execute(input: CheckoutInput) {
    const gateway = this.billingFactory.createCheckoutGateway();
    return gateway.createCheckout(input);
  }
}
```

## C# Example

```csharp
public interface ICheckoutGateway
{
    Task<CheckoutSession> CreateCheckoutAsync(CheckoutInput input, CancellationToken ct);
}

public interface IWebhookVerifier
{
    Task<PaymentEvent> VerifyAsync(string payload, string signature, CancellationToken ct);
}

public interface IBillingProviderFactory
{
    ICheckoutGateway CreateCheckoutGateway();
    IWebhookVerifier CreateWebhookVerifier();
}

public sealed class StripeBillingProviderFactory : IBillingProviderFactory
{
    public ICheckoutGateway CreateCheckoutGateway() => new StripeCheckoutGateway();
    public IWebhookVerifier CreateWebhookVerifier() => new StripeWebhookVerifier();
}
```

## Java Example

```java
public interface BillingProviderFactory {
    CheckoutGateway createCheckoutGateway();
    WebhookVerifier createWebhookVerifier();
}

public final class StripeBillingProviderFactory implements BillingProviderFactory {
    public CheckoutGateway createCheckoutGateway() {
        return new StripeCheckoutGateway();
    }

    public WebhookVerifier createWebhookVerifier() {
        return new StripeWebhookVerifier();
    }
}
```

## Kapan Tidak Perlu

Jangan memakai Abstract Factory bila:

- Hanya ada satu provider dan belum ada rencana realistis menambah provider.
- Object yang dibuat tidak satu keluarga.
- Factory hanya membungkus `new` tanpa mengurangi coupling.
- Conditional sederhana masih cukup jelas.

## Kapan Cocok

Gunakan bila:

- Ada beberapa provider dengan beberapa object yang harus konsisten.
- Provider dipilih dari config atau tenant.
- Test butuh fake provider.
- Modul payment, notification, atau storage ingin tetap independen dari vendor.

## Checklist Implementasi

- Buat interface untuk setiap product.
- Buat abstract factory interface.
- Buat concrete factory per provider.
- Pilih factory di composition root berdasarkan config.
- Inject factory ke use case.
- Jangan pilih provider langsung di controller.
- Tambahkan fake factory untuk test.
