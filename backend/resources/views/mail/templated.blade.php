<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $subjectLine }}</title>
</head>
<body style="margin:0;padding:0;background:#f5f5f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1d1d1f;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f5f7;padding:32px 16px;">
    <tr>
        <td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;">
                <tr>
                    <td style="background:{{ $brandColor }};padding:24px 32px;color:#ffffff;font-size:18px;font-weight:600;">
                        {{ $restaurantName }}
                    </td>
                </tr>
                <tr>
                    <td style="padding:32px;font-size:15px;line-height:1.6;">
                        {!! $htmlBody !!}
                    </td>
                </tr>
                @if ($footer)
                <tr>
                    <td style="padding:0 32px 32px;font-size:12px;color:#86868b;">{{ $footer }}</td>
                </tr>
                @endif
            </table>
        </td>
    </tr>
</table>
</body>
</html>
