<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Models\Role;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

final class CreatePlatformAdmin extends Command
{
    protected $signature = 'platform:create-admin {email} {--name=Platform Admin}';

    protected $description = 'Create a platform administrator (asks for the password interactively).';

    public function handle(): int
    {
        $email = strtolower((string) $this->argument('email'));
        $password = (string) $this->secret('Password (min. 12 characters)');

        $validator = Validator::make(
            ['email' => $email, 'password' => $password],
            ['email' => ['required', 'email', 'unique:users,email'], 'password' => ['required', Password::min(12)->mixedCase()->numbers()]],
        );

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        $user = new User;
        $user->fill(['name' => (string) $this->option('name'), 'email' => $email, 'password' => $password]);
        $user->forceFill([
            'role_id' => Role::findBySlug(RoleSlug::PlatformAdmin)->getKey(),
            'status' => UserStatus::Active,
            'email_verified_at' => Carbon::now(),
            'password_changed_at' => Carbon::now(),
        ])->save();

        $this->info("Platform administrator {$email} created.");

        return self::SUCCESS;
    }
}
