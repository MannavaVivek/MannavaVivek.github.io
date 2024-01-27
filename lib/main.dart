import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'HomePage.dart'; // Import your pages
import 'SearchPage.dart';
import 'FavoritesPage.dart';
import 'UserPage.dart';
import 'content_classes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Isar
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [CountrySchema, CitySchema, RecommendationSchema, UserFavoritesSchema],
    directory: dir.path,
  );

  runApp(MyApp(isar: isar));
}

class MyApp extends StatelessWidget {
  final Isar isar;

  const MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(
        isar: isar,
      ),
    );
  }
}

//TODO: Add isar close in dispose
//TODO: Add logger if print statements are really necessary
class MainScreen extends StatefulWidget {
  final Isar isar;

  const MainScreen({super.key, required this.isar});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages = [
    HomePage(isar: widget.isar),
    SearchPage(isar: widget.isar),
    FavoritesPage(isar: widget.isar),
    UserPage(isar: widget.isar)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showBackDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
            'Are you sure you want to leave this page?',
          ),
          actions: <Widget>[
            TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Stay'),
                onPressed: () {
                  Navigator.pop(context);
                }),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Leave'),
              onPressed: () {
                Navigator.pop(context);
                // exit the app
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchContent(Isar isar) async {
    const String spaceID = 'pqzjijb5vjqz';
    const String accessToken = 'IVqE-SRtoM5IZ8bTHuf0Cwnx3Jb470uML77gX-2mYwQ';
    const String environment = 'master';
    const String countryContentType = 'country';
    List<String> countriesList = [];
    try {
      // Fetch countries
      final countryResponse = await http.get(
        Uri.parse(
          'https://cdn.contentful.com/spaces/$spaceID/environments/$environment/entries?access_token=$accessToken&metadata.tags.sys.id[all]=$countryContentType',
        ),
      );

      if (countryResponse.statusCode == 200) {
        final countryJsonResponse = json.decode(countryResponse.body);
        final countryIncludes = countryJsonResponse['includes'];
        List<dynamic> countryBody = countryJsonResponse['items'];
        List<Country> countries = countryBody
            .map((dynamic item) => Country.fromJson(item, countryIncludes))
            .toList();

        // Save countries to Isar
        await isar.writeTxn(() async {
          for (var country in countries) {
            countriesList.add(country.name);
            await isar.countrys.put(country);
          }
        });
      } else {
        List<Country> cachedCountries =
            await widget.isar.countrys.where().findAll();
        if (cachedCountries.isNotEmpty) {
          print('Main - API Error - Fetched countries from Isar');
        } else {
          throw Exception('Failed to load countries');
        }
      }
      //TODO: Deal with city cache not being available. Right now working on assumption that if countries are cached, cities are cached too

      // Fetch cities
      for (var countryItem in countriesList) {
        String cityContentType = '$countryItem,city';
        final cityResponse = await http.get(
          Uri.parse(
            'https://cdn.contentful.com/spaces/$spaceID/environments/$environment/entries?access_token=$accessToken&metadata.tags.sys.id[all]=$cityContentType',
          ),
        );

        if (cityResponse.statusCode == 200) {
          final cityJsonResponse = json.decode(cityResponse.body);
          final cityIncludes = cityJsonResponse['includes'];
          List<dynamic> cityBody = cityJsonResponse['items'];
          List<City> cities = cityBody
              .map((dynamic item) => City.fromJson(item, cityIncludes))
              .toList();

          // Save cities to Isar
          await isar.writeTxn(() async {
            for (var city in cities) {
              await isar.citys.put(city);
            }
          });
        }
      }
      print('Main - API Success - Fetched countries and cities from API');
      // Fetch recommendations
      const String recommendationContentType = 'recommendedReads';
      final recommendationResponse = await http.get(
        Uri.parse(
          'https://cdn.contentful.com/spaces/$spaceID/environments/$environment/entries?access_token=$accessToken&content_type=$recommendationContentType',
        ),
      );

      if (recommendationResponse.statusCode == 200) {
        final recommendationJsonResponse =
            json.decode(recommendationResponse.body);
        List<Recommendation> recommendations =
            Recommendation.fromApiResponse(recommendationJsonResponse);

        // Save recommendations to Isar
        await isar.writeTxn(() async {
          for (var recommendation in recommendations) {
            await isar.recommendations.put(recommendation);
          }
        });
      } else {
        // Handle error or load cached recommendations if necessary
      }
    } catch (e) {
      throw Exception('Failed to load content');
    }

    //check if user has favorites
    try {
      await widget.isar.userFavorites
          .where()
          .userIdEqualTo("Guest")
          .findFirst();
    } catch (e) {
      //if not, create a new userFavorites object
      await widget.isar.writeTxn(() async {
        await widget.isar.userFavorites
            .put(UserFavorites(userId: "Guest", favBlogPosts: []));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchContent(widget.isar);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) {
          if (didPop) {
            return;
          }
          _showBackDialog();
        },
        child: Scaffold(
            body: Center(
              child: _pages.elementAt(_selectedIndex),
            ),
            bottomNavigationBar: SizedBox(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxWidth: 600.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    // Home Button
                    IconButton(
                      iconSize: 24.0, // Smaller icons
                      padding: EdgeInsets
                          .zero, // Removes default padding around the icon
                      icon: const Icon(Icons.home),
                      onPressed: () => _onItemTapped(0),
                    ),

                    // Search Button
                    IconButton(
                      iconSize: 24.0, // Smaller icons
                      padding: EdgeInsets
                          .zero, // Removes default padding around the icon
                      icon: const Icon(Icons.search),
                      onPressed: () => _onItemTapped(1),
                    ),

                    // Favorites Button
                    IconButton(
                      iconSize: 24.0, // Smaller icons
                      padding: EdgeInsets
                          .zero, // Removes default padding around the icon
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () => _onItemTapped(2),
                    ),

                    // User Button
                    IconButton(
                      iconSize: 24.0, // Smaller icons
                      padding: EdgeInsets
                          .zero, // Removes default padding around the icon
                      icon: const Icon(Icons.person),
                      onPressed: () => _onItemTapped(3),
                    ),
                  ],
                ),
              ),
            )));
  }
}
