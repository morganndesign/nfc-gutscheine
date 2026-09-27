<?php

declare(strict_types=1);

namespace App\Enums;

enum NfcWriteResult: string
{
    /** Checked and allowed; the dashboard is writing. Stays so if the browser was closed mid-way. */
    case InProgress = 'in_progress';
    case Succeeded = 'succeeded';
    /** The tag already carried this card's link and chip; nothing was written. */
    case AlreadyProgrammed = 'already_programmed';
    /** Not written because the tag belongs to another card or is not supported. */
    case Refused = 'refused';
    case Failed = 'failed';
    case Cancelled = 'cancelled';

    public function isFinal(): bool
    {
        return $this !== self::InProgress;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
