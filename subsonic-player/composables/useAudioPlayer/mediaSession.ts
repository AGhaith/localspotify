export function useMediaSession(actions: MediaSessionActions) {
  const { getImageUrl } = useAPI();

  const hasMediaSession =
    typeof navigator !== 'undefined' && 'mediaSession' in navigator;

  /* istanbul ignore next -- @preserve */
  async function onMediaSessionAction(
    details: Parameters<
      NonNullable<Parameters<MediaSession['setActionHandler']>['1']>
    >['0'],
  ) {
    switch (details.action) {
      case MEDIA_SESSION_ACTION_DETAILS.nextTrack:
        await actions[MEDIA_SESSION_ACTION_DETAILS.nextTrack]();
        break;
      case MEDIA_SESSION_ACTION_DETAILS.pause:
      case MEDIA_SESSION_ACTION_DETAILS.stop:
        actions[MEDIA_SESSION_ACTION_DETAILS.pause]();
        break;
      case MEDIA_SESSION_ACTION_DETAILS.play:
        await actions[MEDIA_SESSION_ACTION_DETAILS.play]();
        break;
      case MEDIA_SESSION_ACTION_DETAILS.previousTrack:
        await actions[MEDIA_SESSION_ACTION_DETAILS.previousTrack]();
        break;
      case MEDIA_SESSION_ACTION_DETAILS.seekBackward:
        actions[MEDIA_SESSION_ACTION_DETAILS.seekBackward]();
        break;
      case MEDIA_SESSION_ACTION_DETAILS.seekForward:
        actions[MEDIA_SESSION_ACTION_DETAILS.seekForward]();
        break;
      case MEDIA_SESSION_ACTION_DETAILS.seekTo:
        if (details.seekTime != null) {
          actions[MEDIA_SESSION_ACTION_DETAILS.seekTo](details.seekTime);
        }
        break;
    }
  }

  function getAbsoluteImageUrl(imageSource?: string, size = '512'): string {
    if (!imageSource) return '';
    try {
      const url = getImageUrl(imageSource, size);
      if (!url) return '';
      if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:') || url.startsWith('blob:')) {
        return url;
      }
      if (typeof window !== 'undefined' && window.location) {
        return `${window.location.origin}${url.startsWith('/') ? '' : '/'}${url}`;
      }
      return url;
    } catch {
      return '';
    }
  }

  function setMediaSessionMetadata() {
    if (!(hasMediaSession && actions.hasCurrentTrack.value)) {
      return;
    }

    try {
      const track = actions.currentTrack.value;
      const { album, artist, title } = getTrackDisplayMetadata(track);

      const artworkList: MediaImage[] = [];
      const imageSrc = track?.image;

      if (imageSrc) {
        for (const size of MEDIA_SESSION_ARTWORK_SIZES) {
          const absoluteUrl = getAbsoluteImageUrl(imageSrc, `${size}`);
          if (absoluteUrl) {
            artworkList.push({
              sizes: `${size}x${size}`,
              src: absoluteUrl,
              type: 'image/jpeg',
            });
          }
        }
      }

      navigator.mediaSession.metadata = new MediaMetadata({
        title: title || 'LocalSpotify Music',
        artist: artist || 'Local Server',
        album: album || 'LocalSpotify',
        ...(artworkList.length > 0 ? { artwork: artworkList } : {}),
      });
    } catch (e) {
      console.warn('[MediaSession] Failed to set metadata:', e);
    }
  }

  function setupMediaSessionHandlers() {
    if (!hasMediaSession) {
      return;
    }

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.pause,
      onMediaSessionAction,
    );

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.play,
      onMediaSessionAction,
    );

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.stop,
      onMediaSessionAction,
    );

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.seekTo,
      onMediaSessionAction,
    );

    const nextTrackHandler = actions.canPlayNext.value
      ? onMediaSessionAction
      : null;

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.nextTrack,
      nextTrackHandler,
    );

    const previousTrackHandler = actions.canPlayPrevious.value
      ? onMediaSessionAction
      : null;

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.previousTrack,
      previousTrackHandler,
    );

    const podcastEpisodeHandler = actions.isPodcastEpisode.value
      ? onMediaSessionAction
      : null;

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.seekBackward,
      podcastEpisodeHandler,
    );

    navigator.mediaSession.setActionHandler(
      MEDIA_SESSION_ACTION_DETAILS.seekForward,
      podcastEpisodeHandler,
    );
  }

  function setMediaSessionPlaybackState(state: MediaSession['playbackState']) {
    if (!hasMediaSession) {
      return;
    }

    navigator.mediaSession.playbackState = state;
  }

  function setMediaSessionPositionState() {
    if (
      !(
        hasMediaSession &&
        actions.hasCurrentTrack.value &&
        !actions.isRadioStation.value
      )
    ) {
      return;
    }

    const duration = actions.currentTrack.value.duration;
    if (typeof duration !== 'number' || duration <= 0 || isNaN(duration)) {
      return;
    }

    try {
      const playbackRateIndex = actions.playbackRate.value || 0;
      const speed = PLAYBACK_RATES[playbackRateIndex]?.speed || 1;
      const position = Math.min(
        Math.max(0, actions.currentTime.value || 0),
        duration,
      );

      navigator.mediaSession.setPositionState({
        duration,
        playbackRate: speed,
        position,
      });
    } catch {
      // Ignore position state error on rapid transitions
    }
  }

  return {
    setMediaSessionMetadata,
    setMediaSessionPlaybackState,
    setMediaSessionPositionState,
    setupMediaSessionHandlers,
  };
}
