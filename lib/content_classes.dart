import 'package:isar/isar.dart';

part 'content_classes.g.dart';

@Collection()
class Country {
  Id id = 007;

  final String name;
  final String description;
  final String imageAssetID;
  final String imageAssetURL;

  Country({
    required this.name,
    required this.description,
    required this.imageAssetID,
    required this.imageAssetURL,
  });

  factory Country.fromJson(
      Map<String, dynamic> json, Map<String, dynamic> includes) {
    final fields = json['fields'];

    // Find the asset in the includes.assets list with matching sys.id
    final matchingAsset = includes['Asset'].firstWhere(
      (asset) =>
          asset['sys']['id'] == json['fields']['countryPhoto']['sys']['id'],
      orElse: () => null,
    );

    String imageUrl = "";

    if (matchingAsset != null) {
      imageUrl = matchingAsset['fields']['file']['url'];
      print('Image URL: $imageUrl');
    } else {
      print('No matching asset found');
    }

    return Country(
      name: fields['countryName'],
      description: fields['countryDescription'],
      imageAssetID: fields['countryPhoto']['sys']['id'],
      imageAssetURL: imageUrl,
    );
  }
}

@Collection()
class City {
  Id id = 143;
  final String name;
  final String description;
  final String imageAssetID;
  final String imageAssetURL;

  City({
    required this.name,
    required this.description,
    required this.imageAssetID,
    required this.imageAssetURL,
  });

  factory City.fromJson(
      Map<String, dynamic> json, Map<String, dynamic> includes) {
    // Similar implementation as Country.fromJson
    final fields = json['fields'];

    final matchingAsset = includes['Asset'].firstWhere(
      (asset) => asset['sys']['id'] == json['fields']['cityPhoto']['sys']['id'],
      orElse: () => null,
    );

    String imageUrl = "";
    if (matchingAsset != null) {
      imageUrl = matchingAsset['fields']['file']['url'];
      print('Image URL: $imageUrl');
    } else {
      print('No matching asset found');
    }

    if (fields['cityName'] == null) {
      fields['cityName'] = 'No city name';
    } else if (fields['cityDescription'] == null) {
      fields['cityDescription'] = 'No city description';
    } else if (fields['cityPhoto'] == null) {
      fields['cityPhoto'] = 'No city photo';
    }

    return City(
      name: fields['cityName'],
      description: fields['cityDescription'],
      imageAssetID: fields['cityPhoto']['sys']['id'],
      imageAssetURL: imageUrl,
    );
  }
}
