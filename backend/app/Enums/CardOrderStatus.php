<?php

declare(strict_types=1);

namespace App\Enums;

/** A restaurant's request for new cards. */
enum CardOrderStatus: string
{
    /** Waiting for the platform. */
    case Requested = 'requested';
    /** The platform ordered a batch for it. */
    case Accepted = 'accepted';
    /** The platform said no, with a reason. */
    case Declined = 'declined';
}
