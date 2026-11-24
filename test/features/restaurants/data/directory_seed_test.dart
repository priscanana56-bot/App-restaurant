// =============================================================================
// Tests de l'annuaire sourcé (asset Koudougou).
// -----------------------------------------------------------------------------
// La fiche Snack Time est le seul point sourcé autorisé : une seule entrée,
// des coordonnées publiées, une source HTTPS datée et une réserve explicite.
// Aucun autre établissement n'est inventé pour compléter la zone de livraison.
// =============================================================================

// Encodage du faux bundle.
import 'dart:convert';

// Lecture du fichier réel.
import 'dart:io';

// Type ByteData du faux bundle.
import 'package:flutter/services.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Exception attendue en cas de JSON invalide.
import 'package:koudougou_gourmet/core/error/exceptions.dart';

// Niveau de vérification des fiches ajoutées depuis le cahier de projet.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/koudougou_listing.dart';

// Source testée.
import 'package:koudougou_gourmet/features/restaurants/data/datasources/koudougou_directory_data_source.dart';

/// Faux bundle qui sert le contenu du fichier versionné.
final class _FakeAssetBundle extends AssetBundle {
  /// Construit le bundle à partir du texte [contents].
  _FakeAssetBundle(this.contents);

  /// Contenu JSON servi.
  final String contents;

  @override
  Future<ByteData> load(String key) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(contents));
    return ByteData.sublistView(bytes);
  }
}

/// Lit le vrai annuaire depuis la racine du projet.
String _readRealDirectory() =>
    File('assets/seed/koudougou_directory.json')
        .readAsStringSync(encoding: utf8);

/// Point d'entrée des tests.
void main() {
  group('AssetKoudougouDirectoryDataSource', () {
    test('charge l’annuaire réel sans lever d’exception', () async {
      final AssetKoudougouDirectoryDataSource source =
          AssetKoudougouDirectoryDataSource(
            bundle: _FakeAssetBundle(_readRealDirectory()),
          );

      final listings = await source.load();

      // 33 candidats préexistants + l'unique fiche Snack Time + 18 fiches
      // du cahier de projet.
      expect(listings, hasLength(52));
      expect(listings.first.sourceUrl, startsWith('https://'));
    });

    test(
      'contient UNE seule fiche Snack Time sourcée et géolocalisée',
      () async {
        final AssetKoudougouDirectoryDataSource source =
            AssetKoudougouDirectoryDataSource(
              bundle: _FakeAssetBundle(_readRealDirectory()),
            );

        final listings = await source.load();
        final snackListings = listings
            .where((listing) => listing.name == 'Snack Time')
            .toList();

        expect(snackListings, hasLength(1));
        final snack = snackListings.single;
        expect(snack.id, 'snack-time-bcb');
        expect(snack.hasPosition, isTrue);
        expect(snack.position!.latitude, 12.2469375);
        expect(snack.position!.longitude, -2.3885625);
        expect(snack.hasPhone, isTrue);
        expect(snack.phone, '+22673461247');
        expect(snack.deliveryAvailable, isTrue);
        expect(
          snack.sourceUrl,
          contains('place_id:ChIJ2wSzfI0dLg4RHWRwOW3HzYg'),
        );
        expect(snack.note, contains('Une seule fiche'));
      },
    );

    test('n’invente aucune coordonnée pour les autres fiches', () async {
      final AssetKoudougouDirectoryDataSource source =
          AssetKoudougouDirectoryDataSource(
            bundle: _FakeAssetBundle(_readRealDirectory()),
          );

      final listings = await source.load();
      final positioned = listings.where((listing) => listing.hasPosition);

      expect(positioned.map((listing) => listing.id), <String>[
        'snack-time-bcb',
      ]);
    });

    test(
      'les fiches du cahier de projet n’inventent ni GPS ni URL source',
      () async {
        final AssetKoudougouDirectoryDataSource source =
            AssetKoudougouDirectoryDataSource(
              bundle: _FakeAssetBundle(_readRealDirectory()),
            );

        final listings = await source.load();
        final fromDocument = listings
            .where((listing) => listing.sourceName.contains('Cahier de projet'))
            .toList();

        expect(fromDocument, hasLength(18));
        for (final KoudougouListing listing in fromDocument) {
          expect(listing.hasPosition, isFalse);
          expect(listing.sourceUrl, isEmpty);
          expect(listing.verification, DirectoryVerification.toConfirm);
        }
      },
    );

    test('traduit un annuaire corrompu en CacheException', () async {
      final AssetKoudougouDirectoryDataSource source =
          AssetKoudougouDirectoryDataSource(
            bundle: _FakeAssetBundle('{ JSON invalide'),
          );

      await expectLater(source.load(), throwsA(isA<CacheException>()));
    });
  });
}
