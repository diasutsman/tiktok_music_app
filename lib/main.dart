import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const TikTokMusicApp());
}

class TikTokMusicApp extends StatelessWidget {
  const TikTokMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TikTokLoginPage(),
    );
  }
}

class TikTokLoginPage extends StatefulWidget {
  const TikTokLoginPage({super.key});

  @override
  State<TikTokLoginPage> createState() => _TikTokLoginPageState();
}

class _TikTokLoginPageState extends State<TikTokLoginPage> {
  final CookieManager _cookieManager = CookieManager.instance();
  final String loginUrl = "https://www.tiktok.com/login";
  final String userAgent =
      'Mozilla/5.0 (Linux; Android 9; LG-H870 Build/PKQ1.190522.001) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login to TikTok")),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(loginUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent: userAgent,
          javaScriptEnabled: true,
          clearSessionCache: true,
        ),
        onLoadStop: (controller, url) async {
          final cookiesJS = await controller.evaluateJavascript(
            source: 'document.cookie',
          );
          List<Cookie> cookies = await _cookieManager.getCookies(url: url!);
          try {
            final sessionCookie = cookies
                .map((c) => "${c.name}=${c.value}")
                .join("; ");
            print("sessionCookie: $sessionCookie");
            print(
              'sessionCookie.contains(\'tt_csrf_token\'): ${sessionCookie.contains('tt_csrf_token')}',
            );
            print("cookiesJS: $cookiesJS");

            if (sessionCookie.contains('tt_csrf_token')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MusicListPage(cookies: sessionCookie),
                  ),
                );
              });
            }
            // Pass cookies to next page
          } catch (e) {
            print("Session cookie not found yet.");
          }
        },
      ),
    );
  }
}

class MusicListPage extends StatefulWidget {
  final String cookies;
  const MusicListPage({super.key, required this.cookies});

  @override
  State<MusicListPage> createState() => _MusicListPageState();
}

class _MusicListPageState extends State<MusicListPage> {
  List<dynamic> musicList = [];
  final AudioPlayer player = AudioPlayer();
  final Dio dio = Dio();
  int cursor = 0;
  bool isLoading = false;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    fetchMusic();
  }

  Future<void> fetchMusic() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    const secUid =
        'MS4wLjABAAAAXsIZXifaDjhjuVjalEV8BxZKxvjbjkNZqAFrutVQaeSp2alVV2YeMlAk09KxrfHo';
    const appId = '1988';

    final url =
        'https://www.tiktok.com/api/user/collect/music_list/?cursor=$cursor&count=10&appId=$appId&secUid=$secUid&aid=$appId';

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Cookie': widget.cookies,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 9; LG-H870 Build/PKQ1.190522.001) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36',
          },
        ),
      );

      print('response.data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          musicList.addAll(data['musicList'] ?? []);
          cursor = data['cursor'] ?? 0;
          hasMore = (data['hasMore'] ?? false) || (data['has_more'] ?? false);
        });
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void playMusic(String url) async {
    await player.setUrl(url);
    player.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My TikTok Music List')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: musicList.length,
              itemBuilder: (context, index) {
                final item = musicList[index];
                final music = item['music'];
                return Card(
                  child: ListTile(
                    leading: Image.network(music['coverThumb']),
                    title: Text(music['title']),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => playMusic(music['playUrl']),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          if (hasMore && !isLoading)
            ElevatedButton(
              onPressed: fetchMusic,
              child: const Text('Load More'),
            ),
        ],
      ),
    );
  }
}
