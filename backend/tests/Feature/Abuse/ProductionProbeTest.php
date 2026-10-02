<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use Tests\TestCase;

/**
 * Found by probing production passively (2026-10-02): requests that scanners and bots send — no Accept header, no
 * session — must get a clean answer, never a 500 that floods the error log.
 */
final class ProductionProbeTest extends TestCase
{
    public function test_a_guest_without_an_accept_header_gets_401_json_not_500(): void
    {
        foreach ([['GET', '/api/v1/auth/me'], ['GET', '/api/v1/restaurant/logo'], ['GET', '/api/v1/vouchers/export'],
            ['POST', '/api/v1/vouchers'], ['DELETE', '/api/v1/settings/logo']] as [$method, $uri]) {
            $response = $this->call($method, $uri, server: ['HTTP_ACCEPT' => '*/*']);
            $response->assertStatus(401);
            $this->assertSame('UNAUTHENTICATED', $response->json('code'), "{$method} {$uri}");

            $html = $this->call($method, $uri, server: ['HTTP_ACCEPT' => 'text/html']);
            $html->assertStatus(401);
        }
    }
}
