/**
 * One area's UI texts in all three languages. English defines the keys; German and Bosnian must translate every one
 * of them (a missing or extra key is a compile error).
 */
export function defineMessages<const E extends Record<string, string>>(messages: {
  en: E
  de: { [K in keyof E]: string }
  bs: { [K in keyof E]: string }
}) {
  return messages
}
