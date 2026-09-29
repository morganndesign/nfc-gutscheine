<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Exceptions\Domain\CardAuthenticationFailedException;
use Illuminate\Contracts\Cache\Repository as Cache;
use Illuminate\Contracts\Encryption\Encrypter;
use Illuminate\Support\Str;

/**
 * Live card authentication over a relay: `begin` answers the card's challenge and keeps RndA on the server,
 * `finish` checks the card's answer. A challenge lives 30 seconds and can be finished once. The card key is
 * derived again at `finish`; neither key nor RndA ever leaves the server.
 */
final class CardAuthenticator
{
    public const LIFETIME_SECONDS = 30;

    private const PREFIX = 'card-auth:';

    public function __construct(
        private readonly Cache $cache,
        private readonly Encrypter $encrypter,
    ) {}

    /**
     * @param  string  $uid  7-byte UID (known from the card's verified SUN message)
     * @return array{challenge: string, response: string} response = bytes to relay to the card
     */
    public function begin(CardKeys $keys, string $uid, int $keyNumber, string $encryptedRndB): array
    {
        $step = Ev2FirstAuthentication::respond($keys->applicationKey($uid, $keyNumber), $encryptedRndB);
        $challenge = (string) Str::ulid();

        $this->cache->put(self::PREFIX.$challenge, $this->encrypter->encryptString(json_encode([
            'uid' => bin2hex($uid),
            'key' => $keyNumber,
            'a' => base64_encode($step['rndA']),
            'b' => base64_encode($step['rndB']),
        ], JSON_THROW_ON_ERROR)), self::LIFETIME_SECONDS);

        return ['challenge' => $challenge, 'response' => $step['response']];
    }

    /** Single use: a second finish of the same challenge fails, whatever its answer. */
    public function finish(CardKeys $keys, string $challenge, string $encryptedCardResponse): Ev2Session
    {
        $sealed = $this->cache->pull(self::PREFIX.$challenge);
        if (! is_string($sealed)) {
            throw new CardAuthenticationFailedException;
        }

        /** @var array{uid: string, key: int, a: string, b: string} $state */
        $state = json_decode($this->encrypter->decryptString($sealed), true, 4, JSON_THROW_ON_ERROR);
        $uid = (string) hex2bin($state['uid']);

        return Ev2FirstAuthentication::complete(
            $keys->applicationKey($uid, $state['key']),
            (string) base64_decode($state['a'], true),
            (string) base64_decode($state['b'], true),
            $encryptedCardResponse,
        );
    }
}
