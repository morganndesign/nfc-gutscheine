<?php

declare(strict_types=1);

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Attachment;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

final class TemplatedMail extends Mailable
{
    use Queueable;
    use SerializesModels;

    public function __construct(
        public readonly string $subjectLine,
        public readonly string $htmlBody,
        public readonly string $textBody,
        public readonly string $restaurantName,
        public readonly string $brandColor,
        public readonly ?string $footer,
        /** Language of the template the text came from (de, en, bs): the html lang attribute. */
        public readonly string $language,
        /** @var array{string, string}|null The voucher as a PDF (a digital voucher's sale): [file name, bytes]. */
        public readonly ?array $voucherPdf = null,
        /** One line under the text that points to the attachment, in the template's language. */
        public readonly ?string $attachmentNote = null,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: $this->subjectLine);
    }

    public function content(): Content
    {
        return new Content(
            view: 'mail.templated',
            text: 'mail.templated-text',
        );
    }

    /** @return list<Attachment> */
    public function attachments(): array
    {
        if ($this->voucherPdf === null) {
            return [];
        }
        [$name, $bytes] = $this->voucherPdf;

        return [Attachment::fromData(static fn (): string => $bytes, $name)->withMime('application/pdf')];
    }
}
