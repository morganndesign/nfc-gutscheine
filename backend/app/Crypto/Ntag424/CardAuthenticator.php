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
 * derived again at `finish`; neither key nor RndA ever leaves the server. The caller's context (who asked, for
 * what) travels with the challenge, sealed like RndA.
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
     * Uses the card's K3 (live challenge key; no write rights on the card).
     *
     * @param  string  $uid  7-byte UID (known from the card's verified SUN message)
     * @param  array<string, scalar|null>  $context
     * @return array{challenge: string, response: string} response = E(K3, RndA ‖ RndB'), for the card
     */
    public function begin(CardKeys $keys, string $uid, string $encryptedRndB, array $context = []): array
    {
        $step = Ev2FirstAuthentication::respond($keys->challengeKey($uid), $encryptedRndB);
        $challenge = (string) Str::ulid();

        $this->cache->put(self::PREFIX.$challenge, $this->encrypter->encryptString(json_encode([
            'uid' => bin2hex($uid),
            'a' => base64_encode($step['rndA']),
            'b' => base64_encode($step['rndB']),
            'context' => $context,
        ], JSON_THROW_ON_ERROR)), self::LIFETIME_SECONDS);

        return ['challenge' => $challenge, 'response' => $step['response']];
    }

    /**
     * Single use: a second finish of the same challenge fails, whatever its answer.
     *
     * @param  \Closure(array<string, scalar|null>): CardKeys  $keys  The card keys for the challenge's context
     * @return array{0: Ev2Session, 1: array<string, scalar|null>} the session and the context given at begin
     */
    public function finish(\Closure $keys, string $challenge, string $encryptedCardResponse): array
    {
        $sealed = $this->cache->pull(self::PREFIX.$challenge);
        if (! is_string($sealed)) {
            throw new CardAuthenticationFailedException;
        }

        /** @var array{uid: string, a: string, b: string, context: array<string, scalar|null>} $state */
        $state = json_decode($this->encrypter->decryptString($sealed), true, 4, JSON_THROW_ON_ERROR);
        $uid = (string) hex2bin($state['uid']);

        $session = Ev2FirstAuthentication::complete(
            $keys($state['context'])->challengeKey($uid),
            (string) base64_decode($state['a'], true),
            (string) base64_decode($state['b'], true),
            $encryptedCardResponse,
        );

        return [$session, $state['context']];
    }
}
