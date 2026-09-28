<?php

declare(strict_types=1);

/*
 * Einladungs-E-Mail (neues Konto: Inhaber eines Restaurants oder Mitarbeitende).
 * Platzhalter: :name (Vorname), :restaurant, :inviter, :email (Support-Adresse).
 */
return [
    'subject' => 'Einladung zu GiftCard Pro',
    'headline' => 'Sie wurden zu GiftCard Pro eingeladen.',
    'greeting' => 'Hallo :name,',

    'body_owner' => 'Sie wurden als Inhaber des Restaurants „:restaurant“ zu GiftCard Pro eingeladen.',
    'body_staff' => ':inviter hat Sie eingeladen, für das Restaurant „:restaurant“ Gutscheine mit GiftCard Pro zu verwalten.',
    'body_staff_anonymous' => 'Sie wurden eingeladen, für das Restaurant „:restaurant“ Gutscheine mit GiftCard Pro zu verwalten.',
    'instruction' => 'Bitte klicken Sie auf den folgenden Button, um Ihr Passwort festzulegen und Ihr Konto zu aktivieren.',

    'action' => 'Passwort festlegen',
    'expiry' => 'Dieser Link ist 72 Stunden gültig und kann nur einmal verwendet werden.',

    'support' => 'Sollte der Link abgelaufen sein oder Sie Hilfe benötigen, kontaktieren Sie uns bitte unter:',
    'support_staff' => 'Sollte der Link abgelaufen sein, bitten Sie die Restaurantleitung, Ihnen die Einladung erneut zu senden.',

    'closing' => 'Vielen Dank,',
    'signature' => 'Ihr GiftCard Pro Team',
];
