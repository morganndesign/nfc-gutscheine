<?php

declare(strict_types=1);

namespace App\Enums;

enum PresentmentStatus: string
{
    case Verified = 'verified';
    case Consumed = 'consumed';
}
