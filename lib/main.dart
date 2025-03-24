import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  late final WebViewController _controller;
  String? _cookies;

  final String userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(userAgent)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (url) async {
                final cookies = await _controller.runJavaScriptReturningResult(
                  'document.cookie',
                );
                print("cookies: $cookies");
                if (cookies.toString().toLowerCase().contains('token')) {
                  setState(() {
                    _cookies = cookies.toString().replaceAll('"', '');
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse('https://www.tiktok.com/login'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to TikTok')),
      body: WebViewWidget(controller: _controller),
      floatingActionButton:
          _cookies != null
              ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MusicListPage(cookies: _cookies!),
                    ),
                  );
                },
                label: const Text('Continue'),
                icon: const Icon(Icons.arrow_forward),
              )
              : null,
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
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
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
