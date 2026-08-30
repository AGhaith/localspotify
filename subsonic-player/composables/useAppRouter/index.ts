export function useAppRouter() {
  const router = useRouter();
  const route = useRoute();

  const currentPath = computed(() => route.path);
  const currentName = computed(() => route.name as string | undefined);

  const isHome = computed(
    () => route.path === ROUTE_PATHS.index || route.path === ROUTE_PATHS.home,
  );
  const isLogin = computed(() => route.path === ROUTE_PATHS.login);
  const isLibrary = computed(() => route.path === ROUTE_PATHS.library);

  async function goToHome() {
    return navigateTo({
      name: ROUTE_NAMES.index,
    });
  }

  async function goToLogin(redirectPath?: string) {
    return navigateTo({
      name: ROUTE_NAMES.login,
      query: redirectPath ? { redirect: redirectPath } : undefined,
    });
  }

  async function goToLibrary() {
    return navigateTo({
      name: ROUTE_NAMES.library,
    });
  }

  async function navigate(to: string | Parameters<typeof navigateTo>[0]) {
    return navigateTo(to);
  }

  return {
    currentName,
    currentPath,
    goToHome,
    goToLibrary,
    goToLogin,
    isHome,
    isLibrary,
    isLogin,
    navigate,
    route,
    router,
  };
}
