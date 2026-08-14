import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class NexuoraYoutubePlayer extends StatefulWidget {
  final String? url;
  final bool? autoPlay;
  final bool? looping;
  final bool? mute;
  final bool? showControls;
  final bool? showFullScreen;
  final double? width;
  final double? height;

  const NexuoraYoutubePlayer({
    Key? key,
    this.url,
    this.autoPlay = false,
    this.looping = false,
    this.mute = false,
    this.showControls = true,
    this.showFullScreen = true,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<NexuoraYoutubePlayer> createState() => _NexuoraYoutubePlayerState();
}

class _NexuoraYoutubePlayerState extends State<NexuoraYoutubePlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        loop: widget.looping!,
        mute: widget.mute!,
        showControls: widget.showControls!,
        showFullscreenButton: widget.showFullScreen!,
        enableCaption: true,
        showVideoAnnotations: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerControllerProvider(
      controller: _controller,
      child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height ?? 200,
          child: Container()
      ),
    );
  }
}