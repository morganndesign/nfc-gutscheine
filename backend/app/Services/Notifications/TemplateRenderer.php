<?php

declare(strict_types=1);

namespace App\Services\Notifications;

use App\Models\NotificationTemplate;

/**
 * Renders notification templates. Placeholders use {{ name }} syntax; every value is
 * HTML-escaped, and only whitelisted placeholders are substituted (no code execution).
 */
final class TemplateRenderer
{
    /**
     * @param  array<string, string>  $variables
     * @return array{subject: string, html: string, text: string}
     */
    public function render(NotificationTemplate $template, array $variables): array
    {
        $allowed = NotificationTemplate::PLACEHOLDERS[$template->key] ?? [];
        $variables = array_intersect_key($variables, array_flip($allowed));

        $replace = static function (string $source, bool $escape) use ($variables): string {
            return (string) preg_replace_callback('/\{\{\s*([a-z_]+)\s*\}\}/', static function (array $m) use ($variables, $escape): string {
                $value = $variables[$m[1]] ?? '';

                return $escape ? e($value) : $value;
            }, $source);
        };

        $text = $replace($template->body, false);
        $bodyHtml = nl2br($replace(e($template->body), true), false);

        return [
            'subject' => strip_tags($replace($template->subject, false)),
            'html' => $bodyHtml,
            'text' => $text,
        ];
    }
}
