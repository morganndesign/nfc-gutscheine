<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;

/**
 * Account e-mails are Markdown ({@see MailMessage}): HTML in a line is escaped,
 * but Markdown syntax is not. A name a user typed ("[Konto bestätigen](https://evil.example)") would otherwise become
 * a link in an e-mail sent from the platform's own address. Every link needs a "[", so escaping it (and the backslash
 * that could cancel the escape) keeps such values plain text.
 */
final class MarkdownText
{
    public static function escape(string $value): string
    {
        return str_replace(['\\', '['], ['\\\\', '\\['], $value);
    }
}
