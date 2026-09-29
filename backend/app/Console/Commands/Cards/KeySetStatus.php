<?php

declare(strict_types=1);

namespace App\Console\Commands\Cards;

use App\Enums\CardState;
use App\Enums\KeySetStatus as Status;
use App\Models\Card;
use App\Models\KeySet;
use Illuminate\Console\Command;

/**
 * Moves a key set along active → verify_only → retired. A set is retired only when none of its cards can be
 * presented any more; a retired set verifies nothing.
 */
final class KeySetStatus extends Command
{
    protected $signature = 'cards:key-set:status {version} {status : verify_only or retired}';

    protected $description = 'Stop new batches on a key set (verify_only) or retire it once no card uses it.';

    public function handle(): int
    {
        /** @var KeySet|null $set */
        $set = KeySet::query()->where('version', (string) $this->argument('version'))->first();
        $to = Status::tryFrom((string) $this->argument('status'));
        if ($set === null || $to === null || $to === Status::Active) {
            $this->error('Unknown key set, or a status other than verify_only / retired (a new active set comes from cards:key-set:create).');

            return self::FAILURE;
        }
        if ($set->status === Status::Retired) {
            $this->error('A retired key set never comes back.');

            return self::FAILURE;
        }
        if ($to === Status::Retired) {
            $live = Card::query()->withoutGlobalScopes()->where('key_set_id', $set->getKey())
                ->whereNotIn('state', [CardState::Replaced->value, CardState::Revoked->value, CardState::Lost->value, CardState::Destroyed->value, CardState::QaFailed->value])
                ->count();
            if ($live > 0) {
                $this->error("{$live} cards of this key set are still in use; retire it when they are replaced or revoked.");

                return self::FAILURE;
            }
        }
        $set->forceFill(['status' => $to])->save();
        $this->info("Key set {$set->version} is {$to->value}.");

        return self::SUCCESS;
    }
}
