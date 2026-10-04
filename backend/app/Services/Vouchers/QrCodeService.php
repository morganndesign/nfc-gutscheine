<?php

declare(strict_types=1);

namespace App\Services\Vouchers;

use BaconQrCode\Common\ErrorCorrectionLevel;
use BaconQrCode\Renderer\GDLibRenderer;
use BaconQrCode\Renderer\Image\SvgImageBackEnd;
use BaconQrCode\Renderer\ImageRenderer;
use BaconQrCode\Renderer\RendererStyle\RendererStyle;
use BaconQrCode\Writer;

final class QrCodeService
{
    public function svg(string $content, int $size = 320): string
    {
        $renderer = new ImageRenderer(new RendererStyle($size, 2), new SvgImageBackEnd);

        return (new Writer($renderer))->writeString($content, 'UTF-8', ErrorCorrectionLevel::M());
    }

    /** A PNG for documents that do not draw SVG reliably (the e-mailed voucher PDF). */
    public function png(string $content, int $size = 600): string
    {
        return (new Writer(new GDLibRenderer($size, 2)))->writeString($content, 'UTF-8', ErrorCorrectionLevel::M());
    }
}
