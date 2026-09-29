<?php

declare(strict_types=1);

namespace App\Models\Contracts;

use App\Models\Concerns\HashChained;

/**
 * A model whose rows form hash chains ({@see HashChained}).
 */
interface HashChainedRecord
{
    /** Name of the chain (the table). */
    public static function chainName(): string;

    /**
     * The columns covered by the hash, in a fixed order. Never change this list for existing chains.
     *
     * @return list<string>
     */
    public function chainAttributes(): array;
}
