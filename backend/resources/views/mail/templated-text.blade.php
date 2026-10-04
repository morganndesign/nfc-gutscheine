{{ $restaurantName }}

{!! $textBody !!}
@if ($attachmentNote)

{{ $attachmentNote }}
@endif

@if ($footer)
--
{{ $footer }}
@endif
