export const MOBILE_NAVIGATION: NavigationItem[] = [
  {
    icon: ICONS.home,
    title: 'Home',
    to: {
      name: ROUTE_NAMES.index,
    },
  },
  {
    icon: ICONS.search,
    title: 'Search',
    to: {
      name: ROUTE_NAMES.search,
      params: {
        [ROUTE_PARAM_KEYS.search.mediaType]: ROUTE_MEDIA_TYPE_PARAMS.Tracks,
        [ROUTE_PARAM_KEYS.search.query]: '',
      },
    },
  },
  {
    icon: ICONS.music,
    title: 'Library',
    to: {
      name: ROUTE_NAMES.library,
    },
  },
  {
    icon: ICONS.download,
    title: 'Offline',
    to: {
      name: ROUTE_NAMES.downloads,
    },
  },
];
