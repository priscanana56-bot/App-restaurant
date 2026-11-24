// =============================================================================
// Tests unitaires du sanitizer.
// -----------------------------------------------------------------------------
// Ces tests prouvent que les entrées hostiles sont neutralisées AVANT d'atteindre
// le Domain, le cache ou un plugin externe.
// =============================================================================

// Framework de test Flutter (compatible tests unitaires purs).
import 'package:flutter_test/flutter_test.dart';

// Classe testée.
import 'package:koudougou_gourmet/core/security/input_sanitizer.dart';

/// Point d'entrée des tests.
void main() {
  // ---------------------------------------------------------------------------
  // Recherche
  // ---------------------------------------------------------------------------
  group('InputSanitizer.sanitizeSearchQuery', () {
    test('supprime les balises et compacte les espaces', () {
      // Une balise ne doit jamais subsister dans la requête.
      expect(
        InputSanitizer.sanitizeSearchQuery('  <b>Maquis</b>   du   marché  '),
        'Maquis du marché',
      );
    });

    test('neutralise les caractères de rupture et de contrôle', () {
      // Le point-virgule, les chevrons et le caractère nul sont retirés.
      final String result = InputSanitizer.sanitizeSearchQuery(
        'Tô; <script>\u0000',
      );
      expect(result.contains(';'), isFalse);
      expect(result.contains('<'), isFalse);
      expect(result.contains('\u0000'), isFalse);
    });

    test('borne la longueur maximale', () {
      // 200 caractères saisis, 20 autorisés.
      final String result = InputSanitizer.sanitizeSearchQuery(
        'a' * 200,
        maxLength: 20,
      );
      expect(result.length, 20);
    });

    test('renvoie une chaîne vide pour une entrée nulle', () {
      expect(InputSanitizer.sanitizeSearchQuery(null), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Texte libre
  // ---------------------------------------------------------------------------
  group('InputSanitizer.sanitizePlainText', () {
    test('retire les balises et conserve les sauts de ligne utiles', () {
      // Les sauts de ligne excessifs sont réduits à deux.
      expect(
        InputSanitizer.sanitizePlainText(
          '<b>Poulet</b>\u0000 braisé\n\n\n\nPrêt',
        ),
        'Poulet braisé\n\nPrêt',
      );
    });

    test('remplace les sauts de ligne quand ils sont interdits', () {
      // Mode libellé court : une seule ligne.
      expect(
        InputSanitizer.sanitizePlainText(
          'Poulet\nbraisé',
          allowNewlines: false,
        ),
        'Poulet braisé',
      );
    });

    test('tronque sans dépasser la limite', () {
      // La limite est respectée au caractère près.
      expect(
        InputSanitizer.sanitizePlainText('abcdefghij', maxLength: 5),
        'abcde',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Téléphone
  // ---------------------------------------------------------------------------
  group('InputSanitizer.sanitizePhoneNumber', () {
    test('normalise les formats locaux et internationaux', () {
      // Trois écritures différentes du même numéro.
      expect(InputSanitizer.sanitizePhoneNumber('70 12 34 56'), '+22670123456');
      expect(
        InputSanitizer.sanitizePhoneNumber('+226 70 12 34 56'),
        '+22670123456',
      );
      expect(
        InputSanitizer.sanitizePhoneNumber('0022670123456'),
        '+22670123456',
      );
    });

    test('refuse les numéros incomplets ou mal préfixés', () {
      // Longueur incorrecte.
      expect(InputSanitizer.sanitizePhoneNumber('12 34'), isNull);

      // Préfixe national inexistant.
      expect(InputSanitizer.sanitizePhoneNumber('01 23 45 67'), isNull);

      // Injection de lettres.
      expect(InputSanitizer.sanitizePhoneNumber('70 12 34 56<script>'), isNull);
    });

    test('produit le format WhatsApp sans indicatif +', () {
      // wa.me attend 226XXXXXXXX.
      expect(InputSanitizer.whatsAppNumber('+226 70 12 34 56'), '22670123456');
    });

    test('accepte uniquement les numéros d’urgence courts', () {
      // 17 et 112 sont valides, un numéro complet ne l'est pas.
      expect(InputSanitizer.sanitizeShortNumber('17'), '17');
      expect(InputSanitizer.sanitizeShortNumber('112'), '112');
      expect(InputSanitizer.sanitizeShortNumber('22670123456'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Prix et quantités
  // ---------------------------------------------------------------------------
  group('InputSanitizer.sanitizePriceFcfa', () {
    test('accepte les séparateurs d’espaces et le suffixe FCFA', () {
      // Formats usuels saisis par un gérant.
      expect(InputSanitizer.sanitizePriceFcfa('2 500 FCFA'), 2500);
      expect(InputSanitizer.sanitizePriceFcfa('1500'), 1500);
    });

    test('refuse les décimales, les signes et les valeurs hors bornes', () {
      // Le FCFA ne se divise pas en centimes dans ce contexte.
      expect(InputSanitizer.sanitizePriceFcfa('15,5'), isNull);
      expect(InputSanitizer.sanitizePriceFcfa('-100'), isNull);
      expect(InputSanitizer.sanitizePriceFcfa('999999999'), isNull);
    });
  });

  group('InputSanitizer.sanitizeQuantity', () {
    test('borne la quantité entre 1 et le maximum', () {
      // Valeurs valides et limites.
      expect(InputSanitizer.sanitizeQuantity('2'), 2);
      expect(InputSanitizer.sanitizeQuantity('0'), isNull);
      expect(InputSanitizer.sanitizeQuantity('100'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // URLs
  // ---------------------------------------------------------------------------
  group('InputSanitizer.sanitizeUrl', () {
    test('accepte une URL HTTPS de domaine public', () {
      // Cas nominal WhatsApp.
      final Uri? uri = InputSanitizer.sanitizeUrl('https://wa.me/22670123456');
      expect(uri, isNotNull);
      expect(uri?.host, 'wa.me');
    });

    test('refuse les schémas dangereux et les identifiants embarqués', () {
      // Injection JavaScript classique.
      expect(InputSanitizer.sanitizeUrl('javascript:alert(1)'), isNull);

      // Identifiants dans l'autorité (hameçonnage).
      expect(InputSanitizer.sanitizeUrl('https://wa.me@evil.example/'), isNull);

      // Port non standard.
      expect(InputSanitizer.sanitizeUrl('https://wa.me:8443/x'), isNull);
    });

    test('refuse le HTTP en clair par défaut', () {
      // Aucune communication non chiffrée.
      expect(InputSanitizer.sanitizeUrl('http://wa.me/x'), isNull);
    });

    test('valide les coordonnées du schéma geo', () {
      // Coordonnées de Koudougou.
      final Uri? valid = InputSanitizer.sanitizeUrl(
        'geo:12.2528,-2.3669',
        allowedSchemes: <String>{'geo'},
      );
      expect(valid, isNotNull);

      // Latitude hors bornes.
      expect(
        InputSanitizer.sanitizeUrl(
          'geo:120,-2.3669',
          allowedSchemes: <String>{'geo'},
        ),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Identifiants, e-mail et recherche normalisée
  // ---------------------------------------------------------------------------
  group('InputSanitizer (divers)', () {
    test('accepte un identifiant simple et rejette le reste', () {
      // Identifiant technique sûr.
      expect(InputSanitizer.sanitizeIdentifier('resto_01-A'), 'resto_01-A');

      // Espaces et slash interdits.
      expect(InputSanitizer.sanitizeIdentifier('resto 01'), isEmpty);
      expect(InputSanitizer.sanitizeIdentifier('../etc/passwd'), isEmpty);
    });

    test('normalise les e-mails en minuscules', () {
      // Casse et espaces absorbés.
      expect(
        InputSanitizer.sanitizeEmail(' Test@Example.BF '),
        'test@example.bf',
      );
      expect(InputSanitizer.sanitizeEmail('test@'), isNull);
    });

    test('normalise les accents pour la recherche locale', () {
      // « Tô » doit correspondre à « to ».
      expect(
        InputSanitizer.normalizeForSearch('Tô au Soumbala'),
        'to au soumbala',
      );
      expect(InputSanitizer.normalizeForSearch('Chez l’Ami'), 'chez l ami');
    });
  });
}
