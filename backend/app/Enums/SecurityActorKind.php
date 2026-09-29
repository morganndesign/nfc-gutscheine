<?php

declare(strict_types=1);

namespace App\Enums;

/** Who caused a security event. */
enum SecurityActorKind: string
{
    /** A signed-in person on the web (session) or with an integration token. */
    case User = 'user';
    /** A person using the waiter app with a device-bound token. */
    case Device = 'device';
    /** Scheduled or queued work. */
    case System = 'system';
    /** Nobody is signed in (a sign-in attempt, a reset link). */
    case Anonymous = 'anonymous';
}
