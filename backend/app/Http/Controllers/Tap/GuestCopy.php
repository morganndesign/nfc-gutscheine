<?php

declare(strict_types=1);

namespace App\Http\Controllers\Tap;

/** Texts of the guest's tap page, in the restaurant's language (or the phone's, before the card is known). */
final class GuestCopy
{
    private const TEXT = [
        'de' => [
            'title' => 'Ihr Gutschein',
            'balance' => 'Guthaben',
            'no_expiry' => 'Unbefristet gültig',
            'valid_until' => 'Gültig bis',
            'not_verified' => 'Die Karte konnte nicht geprüft werden. Bitte halten Sie sie noch einmal ans Handy.',
            'not_active' => 'Diese Karte ist noch nicht aktiviert.',
            'suspended' => 'Diese Karte ist vorübergehend gesperrt. Bitte wenden Sie sich an das Lokal.',
            'invalid' => 'Diese Karte ist nicht mehr gültig. Bitte wenden Sie sich an das Lokal.',
            'blocked' => 'Dieser Gutschein ist gesperrt. Bitte wenden Sie sich an das Lokal.',
            'expired' => 'Dieser Gutschein ist abgelaufen. Das Lokal kann ihn wieder freischalten.',
            'ask' => 'Das Guthaben erfahren Sie im Lokal.',
            'pay' => 'Zum Bezahlen die Karte an der Kassa vorzeigen.',
        ],
        'en' => [
            'title' => 'Your voucher',
            'balance' => 'Balance',
            'no_expiry' => 'No expiry date',
            'valid_until' => 'Valid until',
            'not_verified' => 'The card could not be checked. Please hold it to your phone again.',
            'not_active' => 'This card is not activated yet.',
            'suspended' => 'This card is temporarily blocked. Please contact the restaurant.',
            'invalid' => 'This card is no longer valid. Please contact the restaurant.',
            'blocked' => 'This voucher is blocked. Please contact the restaurant.',
            'expired' => 'This voucher has expired. The restaurant can reinstate it.',
            'ask' => 'Please ask the restaurant for the balance.',
            'pay' => 'To pay, show the card at the till.',
        ],
        'bs' => [
            'title' => 'Vaš vaučer',
            'balance' => 'Stanje',
            'no_expiry' => 'Bez roka važenja',
            'valid_until' => 'Vrijedi do',
            'not_verified' => 'Kartica se nije mogla provjeriti. Molimo prislonite je ponovo uz telefon.',
            'not_active' => 'Ova kartica još nije aktivirana.',
            'suspended' => 'Ova kartica je privremeno blokirana. Molimo obratite se restoranu.',
            'invalid' => 'Ova kartica više nije važeća. Molimo obratite se restoranu.',
            'blocked' => 'Ovaj vaučer je blokiran. Molimo obratite se restoranu.',
            'expired' => 'Ovaj vaučer je istekao. Restoran ga može ponovo aktivirati.',
            'ask' => 'Stanje možete saznati u restoranu.',
            'pay' => 'Za plaćanje pokažite karticu na kasi.',
        ],
    ];

    /** @return array<string, string> */
    public static function for(string $language): array
    {
        return self::TEXT[$language] ?? self::TEXT['en'];
    }

    public static function language(?string $locale): string
    {
        return match (strtolower(substr((string) $locale, 0, 2))) {
            'de' => 'de',
            'bs', 'hr', 'sr' => 'bs',
            default => 'en',
        };
    }
}
