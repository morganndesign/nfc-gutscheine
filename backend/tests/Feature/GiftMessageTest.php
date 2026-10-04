<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Voucher;
use App\Services\Vouchers\VoucherPdf;
use Tests\TestCase;

/** A voucher bought for someone: their name and the buyer's message on the voucher and its PDF (decision 2026-10-04). */
final class GiftMessageTest extends TestCase
{
    public function test_the_sale_stores_the_recipient_and_the_trimmed_message(): void
    {
        $this->actingAsStaff($this->restaurant());

        $response = $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => 3000,
            'form' => 'printable',
            'payment' => $this->cashPayment(),
            'recipient_name' => 'Anna',
            'gift_message' => "  Alles Gute zum Geburtstag!\n",
        ])->assertCreated()
            ->assertJsonPath('data.recipient_name', 'Anna')
            ->assertJsonPath('data.gift_message', 'Alles Gute zum Geburtstag!');

        $this->assertSame('Alles Gute zum Geburtstag!', Voucher::query()->findOrFail($response->json('data.id'))->gift_message);
    }

    public function test_a_message_longer_than_300_characters_is_refused(): void
    {
        $this->actingAsStaff($this->restaurant());

        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => 3000,
            'form' => 'printable',
            'payment' => $this->cashPayment(),
            'gift_message' => str_repeat('x', 301),
        ])->assertUnprocessable()->assertJsonValidationErrors('gift_message');
        $this->assertSame(0, Voucher::query()->count());
    }

    public function test_the_message_can_be_corrected_and_removed_later(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant);
        $id = $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'gift_message' => 'Alles Gutte',
        ])->assertCreated()->json('data.id');

        $this->patchJson("/api/v1/vouchers/{$id}", ['gift_message' => 'Alles Gute'])->assertOk()->assertJsonPath('data.gift_message', 'Alles Gute');
        $this->patchJson("/api/v1/vouchers/{$id}", ['gift_message' => null])->assertOk()->assertJsonPath('data.gift_message', null);
    }

    public function test_the_pdf_shows_the_recipient_and_the_buyers_words_escaped(): void
    {
        $restaurant = $this->restaurant(['locale' => 'de_AT']);
        $restaurant->settings->update(['voucher_message' => 'Wir freuen uns auf Sie.']);
        $this->actingAsStaff($restaurant);
        $response = $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment(),
            'recipient_name' => 'Anna <b>', 'gift_message' => 'Genieß den Abend <script>',
        ])->assertCreated();
        $voucher = Voucher::query()->findOrFail($response->json('data.id'));

        $html = app(VoucherPdf::class)->html($voucher, (string) $response->json('printable.payload'));
        $this->assertStringContainsString('für Anna &lt;b&gt;', $html);
        // The buyer's words replace the restaurant's message, in German quotes.
        $this->assertStringContainsString('„Genieß den Abend &lt;script&gt;“', $html);
        $this->assertStringNotContainsString('<script>', $html);
        $this->assertStringNotContainsString('Wir freuen uns auf Sie.', $html);
        $this->assertStringStartsWith('%PDF-', app(VoucherPdf::class)->render($voucher, (string) $response->json('printable.payload')));
    }

    public function test_without_a_message_the_pdf_keeps_the_restaurants_message(): void
    {
        $restaurant = $this->restaurant(['locale' => 'de_AT']);
        $restaurant->settings->update(['voucher_message' => 'Wir freuen uns auf Sie.']);
        $this->actingAsStaff($restaurant);
        $response = $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment(),
        ])->assertCreated();

        $html = app(VoucherPdf::class)->html(Voucher::query()->findOrFail($response->json('data.id')), (string) $response->json('printable.payload'));
        $this->assertStringContainsString('<div class="message">Wir freuen uns auf Sie.</div>', $html);
        $this->assertStringNotContainsString('class="for"', $html);
    }
}
