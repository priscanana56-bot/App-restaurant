// =============================================================================
// Référentiel local de Koudougou.
// -----------------------------------------------------------------------------
// Contient les repères géographiques, secteurs et contacts d'urgence utilisés
// par l'interface. Ces données sont publiques mais doivent être vérifiées sur
// le terrain avant chaque mise en production (voir commentaires).
// =============================================================================

/// Contact d'urgence ou institutionnel affiché dans l'application.
/// Classe immuable : toutes les propriétés sont `final`.
final class EmergencyContact {
  // Constructeur constant pour permettre des listes `const` sans allocation.
  const EmergencyContact({
    required this.label,
    required this.phone,
    required this.description,
  });

  /// Libellé court affiché sur le bouton (ex. « Police »).
  final String label;

  /// Numéro composable, au format court local (ex. « 17 »).
  final String phone;

  /// Précision affichée sous le libellé.
  final String description;
}

/// Opérateur de paiement mobile accepté par les maquis partenaires.
final class MobileMoneyOperator {
  // Constructeur constant : liste d'opérateurs compilée en dur, sans I/O.
  const MobileMoneyOperator({
    required this.name,
    required this.ussdCode,
    required this.instructions,
  });

  /// Nom commercial de l'opérateur (Orange Money, Moov Money...).
  final String name;

  /// Code USSD à composer depuis le téléphone pour ouvrir le menu de paiement.
  final String ussdCode;

  /// Consigne courte affichée dans la feuille de commande.
  final String instructions;
}

/// Données de référence de la ville de Koudougou.
final class KoudougouReference {
  // Constructeur privé : espace de noms statique.
  const KoudougouReference._();

  // ---------------------------------------------------------------------------
  // Découpage administratif et repères
  // ---------------------------------------------------------------------------

  /// Secteurs administratifs de Koudougou.
  /// À valider avec la mairie : le découpage peut évoluer.
  static const List<String> sectors = <String>[
    'Secteur 1',
    'Secteur 2',
    'Secteur 3',
    'Secteur 4',
    'Secteur 5',
    'Secteur 6',
    'Secteur 7',
    'Secteur 8',
    'Secteur 9',
    'Secteur 10',
    'Secteur 11',
    'Secteur 12',
  ];

  /// Repères géographiques connus, utilisés comme filtres et comme complément
  /// d'adresse lorsque le GPS est imprécis.
  static const List<String> landmarks = <String>[
    'Grand marché',
    'Gare routière',
    'Zone universitaire (Université Norbert Zongo)',
    'Route de Ouagadougou',
    'Route de Bobo-Dioulasso',
    'Route de Dédougou',
    'Stade Balibié',
    'Lycée municipal',
    'Centre-ville',
    'Quartier administratif',
  ];

  // ---------------------------------------------------------------------------
  // Contacts d'urgence (numéros nationaux, à vérifier avant publication)
  // ---------------------------------------------------------------------------

  /// Numéros d'urgence standards du Burkina Faso.
  static const List<EmergencyContact> emergencyContacts = <EmergencyContact>[
    EmergencyContact(
      label: 'Police secours',
      phone: '17',
      description: 'Police nationale — urgences',
    ),
    EmergencyContact(
      label: 'Sapeurs-pompiers',
      phone: '18',
      description: 'Incendie, accident, secours à personne',
    ),
    EmergencyContact(
      label: 'Urgences générales',
      phone: '112',
      description: 'Numéro d’urgence mobile',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Paiement mobile
  // ---------------------------------------------------------------------------

  /// Opérateurs Mobile Money à proposer dans le récapitulatif de commande.
  /// Les codes USSD doivent être confirmés auprès des opérateurs : ils peuvent
  /// changer et ne constituent pas une garantie contractuelle.
  static const List<MobileMoneyOperator> mobileMoneyOperators =
      <MobileMoneyOperator>[
        MobileMoneyOperator(
          name: 'Orange Money',
          ussdCode: '#144#',
          instructions: 'Composez #144#, choisissez « Paiement marchand » puis saisissez le code du restaurant.',
        ),
        MobileMoneyOperator(
          name: 'Moov Money',
          ussdCode: '*155#',
          instructions: 'Composez *155#, choisissez « Payer un marchand » puis validez le montant affiché.',
        ),
      ];

  /// Avertissement affiché avant tout paiement.
  /// L'application ne manipule jamais d'argent : elle fournit uniquement des
  /// instructions et ne collecte aucun code PIN.
  static const String paymentSafetyNotice =
      'Ne communiquez jamais votre code PIN. Le paiement se fait uniquement '
      'via le code marchand officiel affiché par le restaurant.';
}
