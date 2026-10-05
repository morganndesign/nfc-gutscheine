<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Support\Heartbeat;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * GET /health/operations, for the external uptime monitor: 200 "ok" when the database answers and the scheduler
 * and the queue worker are alive and e-mail really leaves the server (sign-in codes depend on it); 503 "degraded" otherwise (which check failed is logged, not shown). /up stays
 * the plain liveness check of the web service used by deploys.
 */
final class OperationsHealthController extends Controller
{
    public function __invoke(): Response
    {
        $failing = [];
        try {
            DB::connection()->select('select 1');
        } catch (Throwable) {
            $failing[] = 'database';
        }
        foreach ([Heartbeat::SCHEDULER, Heartbeat::WORKER] as $service) {
            if (! Heartbeat::fresh($service)) {
                $failing[] = $service;
            }
        }
        // Sign-in needs the e-mailed code: a mailer that only writes to the log locks everybody out (audit S2).
        if (app()->isProduction() && in_array(config('mail.default'), ['log', 'array'], true)) {
            $failing[] = 'mail';
        }
        if ($failing !== []) {
            Log::critical('Operations health check failing', ['failing' => $failing]);
        }

        return response($failing === [] ? 'ok' : 'degraded', $failing === [] ? 200 : 503)
            ->header('Content-Type', 'text/plain')
            ->header('Cache-Control', 'no-store');
    }
}
