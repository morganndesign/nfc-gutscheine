import { defineMessages } from "@/lib/i18n/define"

/**
 * API error codes (`errors.<CODE>`) the user may see, and the generic ones. A code without an entry shows the
 * server's message. VALIDATION_FAILED is deliberately absent: its field messages are already localised.
 */
export const errors = defineMessages({
  en: {
    "errors.generic": "Something went wrong. Please try again.",
    "errors.offline": "No connection to the server. Check the internet connection and try again.",
  },
  de: {
    "errors.generic": "Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.",
    "errors.offline": "Keine Verbindung zum Server. Prüfen Sie die Internetverbindung und versuchen Sie es erneut.",
  },
  bs: {
    "errors.generic": "Nešto nije u redu. Pokušajte ponovo.",
    "errors.offline": "Nema veze sa serverom. Provjerite internet vezu i pokušajte ponovo.",
  },
})
