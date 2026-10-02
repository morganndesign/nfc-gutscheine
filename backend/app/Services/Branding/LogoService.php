<?php

declare(strict_types=1);

namespace App\Services\Branding;

use App\Models\Restaurant;
use App\Models\RestaurantLogo;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Stores a restaurant's logo. The upload is decoded and drawn again (PNG, transparency kept, at most 1200 px), so
 * what is served is always a clean image: no metadata, no polyglot or script payload of the original file.
 */
final class LogoService
{
    private const MAX_SIDE = 1200;

    private const MIN_SIDE = 32;

    /**
     * Largest source accepted, checked from the file header before decoding: GD holds 4 bytes per pixel, so a few
     * hundred kilobytes of PNG declaring 12000 × 12000 pixels would need over half a gigabyte (decompression bomb).
     * 4096 × 4096 (~64 MB decoded) still fits a PHP-FPM worker with its default 128 MB.
     */
    private const MAX_SOURCE_SIDE = 4096;

    public function __construct(private readonly AuditLogger $audit) {}

    public function store(Actor $actor, Restaurant $restaurant, UploadedFile $file): RestaurantLogo
    {
        $bytes = (string) file_get_contents($file->getRealPath());
        $info = @getimagesizefromstring($bytes);
        if ($info === false || ! in_array($info[2], [IMAGETYPE_PNG, IMAGETYPE_JPEG], true)) {
            throw ValidationException::withMessages(['logo' => __('api.logo_unreadable')]);
        }
        if (max($info[0], $info[1]) > self::MAX_SOURCE_SIDE) {
            throw ValidationException::withMessages(['logo' => __('api.logo_too_large', ['max' => self::MAX_SOURCE_SIDE])]);
        }

        $source = @imagecreatefromstring($bytes);
        unset($bytes);
        if (! $source instanceof GdImage) {
            throw ValidationException::withMessages(['logo' => __('api.logo_unreadable')]);
        }
        [$width, $height] = [imagesx($source), imagesy($source)];
        if (min($width, $height) < self::MIN_SIDE) {
            throw ValidationException::withMessages(['logo' => __('api.logo_too_small', ['min' => self::MIN_SIDE])]);
        }

        $scale = min(1, self::MAX_SIDE / max($width, $height));
        $w = max(1, (int) round($width * $scale));
        $h = max(1, (int) round($height * $scale));
        $canvas = imagecreatetruecolor($w, $h);
        imagealphablending($canvas, false);
        imagesavealpha($canvas, true);
        imagefill($canvas, 0, 0, (int) imagecolorallocatealpha($canvas, 0, 0, 0, 127));
        imagecopyresampled($canvas, $source, 0, 0, 0, 0, $w, $h, $width, $height);

        ob_start();
        imagepng($canvas, null, 9);
        $png = (string) ob_get_clean();

        return DB::transaction(function () use ($actor, $restaurant, $png, $w, $h): RestaurantLogo {
            $logo = RestaurantLogo::query()->updateOrCreate(
                ['restaurant_id' => $restaurant->getKey()],
                ['mime' => 'image/png', 'width' => $w, 'height' => $h, 'data' => base64_encode($png)],
            );
            $settings = $restaurant->settings;
            $settings->logo_version = hash('sha256', $png);
            $settings->save();
            $this->audit->log('restaurant.logo_updated', $actor, $settings, null, ['width' => $w, 'height' => $h]);

            return $logo;
        });
    }

    public function remove(Actor $actor, Restaurant $restaurant): void
    {
        DB::transaction(function () use ($actor, $restaurant): void {
            RestaurantLogo::query()->whereKey($restaurant->getKey())->delete();
            $settings = $restaurant->settings;
            if ($settings->logo_version !== null) {
                $settings->logo_version = null;
                $settings->save();
                $this->audit->log('restaurant.logo_removed', $actor, $settings);
            }
        });
    }
}
