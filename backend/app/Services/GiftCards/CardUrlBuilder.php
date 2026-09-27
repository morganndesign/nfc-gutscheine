<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

use App\Enums\NfcTagType;
use App\Models\GiftCard;

/**
 * Builds the only data ever written to a physical card: a URL containing the random public token.
 */
final class CardUrlBuilder
{
    public const TOKEN_PATTERN = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}';

    public function url(GiftCard $card): string
    {
        return $this->urlForToken($card->public_token);
    }

    public function urlForToken(string $token): string
    {
        return config('giftcard.card_base_url').'/c/'.$token;
    }

    /**
     * NDEF URL template for NTAG 424 DNA provisioning. The SDM engine of the chip replaces the
     * zero placeholders with encrypted PICC data and the MAC on every tap.
     */
    public function secureTemplate(GiftCard $card): string
    {
        return $this->url($card).'?picc='.str_repeat('0', 32).'&cmac='.str_repeat('0', 16);
    }

    /** @return array{url: string, tag_type_hint: string, ndef_template: string|null} */
    public function payloadFor(GiftCard $card, ?NfcTagType $tagType = null): array
    {
        $tagType ??= $card->nfc_tag_type;

        return [
            'url' => $this->url($card),
            'tag_type_hint' => $tagType->value ?? NfcTagType::Ntag215->value,
            'ndef_template' => $tagType === NfcTagType::Ntag424Dna ? $this->secureTemplate($card) : null,
        ];
    }

    /** Extracts a public token from a scanned URL or a raw token string. */
    public function extractToken(string $input): ?string
    {
        $input = trim($input);

        if (preg_match('~(?:^|/c/)('.self::TOKEN_PATTERN.')(?:[/?#]|$)~', $input, $m) === 1) {
            return strtolower($m[1]);
        }

        return null;
    }
}
