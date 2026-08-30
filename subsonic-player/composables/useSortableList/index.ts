export function useSortableList(options: SortableListOptions) {
  const { listContainerRef, onReorder } = options;

  const { isDragging, setDraggingState } = useSortableListState();

  // DOM references.
  const draggedItem = ref<HTMLElement | null>(null);
  const spacerElement = ref<HTMLElement | null>(null);
  const scrollableAncestor = ref<HTMLElement | null>(null);
  const items = ref<HTMLElement[]>([]);

  // Event management.
  const listenerAbortController = ref<AbortController | null>(null);
  const dragAbortController = ref<AbortController | null>(null);
  const animationFrameId = ref<null | number>(null);
  let moveRafId: number | null = null;

  // Touch long-press state.
  const longPressTimer = ref<null | ReturnType<typeof setTimeout>>(null);
  const pendingTouchStartX = ref(0);
  const pendingTouchStartY = ref(0);

  let listMutationObserver: MutationObserver | null = null;
  const dragState = createInitialDragState();

  function resolveListContainer() {
    return getListContainerElement(listContainerRef.value);
  }

  function createInitialDragState() {
    return {
      containerHeight: 0,
      containerTop: 0,
      initialItemRects: new Map<HTMLElement, DOMRect>(),
      initialItemTop: 0,
      initialScrollTop: 0,
      isAutoScrolling: false,
      itemHeight: 0,
      lastPointerY: 0,
      pointerStartY: 0,
    };
  }

  // Clears the cached items list and re-queries the DOM, marking all items as idle.
  function refreshSortableItems() {
    items.value = [];
    getSortableListItems().forEach((item) => {
      item.classList.add(SORTABLE_LIST_CLASS_NAMES.idle);
    });
  }

  // Lazily queries and caches all sortable item elements within the container.
  function getSortableListItems() {
    const listContainerElement = resolveListContainer();

    if (!items.value.length && listContainerElement) {
      items.value = Array.from(
        listContainerElement.querySelectorAll(
          `.${SORTABLE_LIST_CLASS_NAMES.item}`,
        ),
      );
    }

    return items.value;
  }

  // Returns only the items that are not currently being dragged.
  function getIdleSortableItems() {
    return getSortableListItems().filter((item) =>
      item.classList.contains(SORTABLE_LIST_CLASS_NAMES.idle),
    );
  }

  // Binds all event listeners (mouse/touch) to the list container and sets up
  // a MutationObserver to re-sync items when children are added or removed.
  function setupSortableInteractions() {
    const listContainerElement = resolveListContainer();

    if (!listContainerElement) {
      return;
    }

    // Tear down any previous listeners before re-attaching.
    listenerAbortController.value?.abort();
    listMutationObserver?.disconnect();

    refreshSortableItems();

    listenerAbortController.value = new AbortController();
    const { signal } = listenerAbortController.value;

    listContainerElement.addEventListener('mousedown', onPointerDown, {
      signal,
    });
    listContainerElement.addEventListener('touchstart', onPointerDown, {
      passive: true,
      signal,
    });
    document.addEventListener('touchmove', onTouchMoveBeforeDrag, {
      passive: true,
      signal,
    });
    document.addEventListener('mouseup', onPointerUp, {
      signal,
    });
    document.addEventListener('touchend', onPointerUp, {
      passive: true,
      signal,
    });
    document.addEventListener('touchcancel', onPointerUp, {
      passive: true,
      signal,
    });

    listMutationObserver = new MutationObserver(() => {
      requestAnimationFrame(() => {
        if (!isDragging.value) {
          refreshSortableItems();
        }
      });
    });

    listMutationObserver.observe(listContainerElement, {
      childList: true,
      subtree: false,
    });
  }

  function cancelLongPress() {
    if (longPressTimer.value !== null) {
      clearTimeout(longPressTimer.value);
      longPressTimer.value = null;
    }
  }

  // Handles mousedown/touchstart - finds the drag handle and sortable item,
  // then either starts a drag immediately (mouse) or begins a long-press timer (touch).
  function onPointerDown(event: MouseEvent | TouchEvent) {
    if (draggedItem.value) {
      return;
    }

    const target = event.target;

    if (!(target instanceof Element)) {
      return;
    }

    if (!findClosestElement(target, SORTABLE_LIST_CLASS_NAMES.dragHandle)) {
      return;
    }

    const sortableItemElement = findClosestElement(
      target,
      SORTABLE_LIST_CLASS_NAMES.item,
    );

    if (!sortableItemElement) {
      return;
    }

    if (event instanceof TouchEvent) {
      startLongPressTimer(event, sortableItemElement);
      return;
    }

    event.preventDefault();
    setDraggingState(true);
    initializeDragSession(
      sortableItemElement,
      getPointerEventPosition(event)?.clientY || 0,
    );
  }

  // Starts a long-press timer for touch drag initiation.
  function startLongPressTimer(event: TouchEvent, element: HTMLElement) {
    const position = getPointerEventPosition(event);
    const startX = position?.clientX || 0;
    const startY = position?.clientY || 0;

    pendingTouchStartX.value = startX;
    pendingTouchStartY.value = startY;

    cancelLongPress();
    longPressTimer.value = setTimeout(() => {
      longPressTimer.value = null;
      navigator.vibrate?.(40);
      setDraggingState(true);
      initializeDragSession(element, startY);
    }, TOUCH_LONG_PRESS_DELAY);
  }

  // Cancels the long-press if the finger moves too far before the timer fires.
  function onTouchMoveBeforeDrag(event: TouchEvent) {
    if (longPressTimer.value === null) {
      return;
    }

    const position = getPointerEventPosition(event);
    const touchMovedX = Math.abs(
      (position?.clientX || 0) - pendingTouchStartX.value,
    );
    const touchMovedY = Math.abs(
      (position?.clientY || 0) - pendingTouchStartY.value,
    );

    if (
      touchMovedX > TOUCH_MOVE_TOLERANCE ||
      touchMovedY > TOUCH_MOVE_TOLERANCE
    ) {
      cancelLongPress();
    }
  }

  // Sets up all state needed for a drag: captures initial positions of every item,
  // finds the scrollable ancestor, and starts auto-scroll + pointer-move listeners.
  function initializeDragSession(item: HTMLElement, startY: number) {
    draggedItem.value = item;
    dragState.pointerStartY = startY;
    dragState.lastPointerY = startY;

    const listContainerElement = resolveListContainer();
    scrollableAncestor.value =
      findScrollableParentElement(listContainerElement);
    dragState.initialScrollTop = getCurrentScrollTop(scrollableAncestor.value);
    dragState.containerTop =
      listContainerElement?.getBoundingClientRect().top || 0;
    dragState.containerHeight = listContainerElement?.scrollHeight || 0;

    items.value = [];
    dragState.initialItemRects.clear();
    getSortableListItems().forEach((it) => {
      dragState.initialItemRects.set(it, it.getBoundingClientRect());
    });

    setDocumentDraggingStyles(true);
    initializeDraggedItem();
    markItemsAboveDraggedItem();

    stopAutoScroll();
    animationFrameId.value = requestAnimationFrame(performAutoScroll);

    dragAbortController.value?.abort();
    dragAbortController.value = new AbortController();
    const { signal: dragSignal } = dragAbortController.value;

    document.addEventListener('mousemove', onPointerMove, {
      signal: dragSignal,
    });
    document.addEventListener('touchmove', onPointerMove, {
      passive: false,
      signal: dragSignal,
    });
  }

  // Pulls the dragged item out of normal flow by positioning it absolutely,
  // and inserts a spacer div to keep the remaining items spaced correctly.
  function initializeDraggedItem() {
    if (!draggedItem.value) {
      return;
    }

    const listContainerElement = resolveListContainer();
    const rect = draggedItem.value.getBoundingClientRect();
    const containerRect = listContainerElement?.getBoundingClientRect();

    const allItems = getSortableListItems();
    const draggedIndex = allItems.indexOf(draggedItem.value);
    let stepHeight = rect.height;
    if (allItems.length > 1) {
      const otherItem = allItems[draggedIndex === 0 ? 1 : 0];
      if (otherItem) {
        const otherRect = otherItem.getBoundingClientRect();
        const dist = Math.abs(otherRect.top - rect.top);
        if (dist > 0) {
          stepHeight = dist;
        }
      }
    }

    dragState.initialItemTop = rect.top;
    dragState.itemHeight = stepHeight;

    spacerElement.value = document.createElement('div');
    spacerElement.value.style.height = `${rect.height}px`;
    draggedItem.value.parentNode?.insertBefore(
      spacerElement.value,
      draggedItem.value.nextSibling,
    );

    draggedItem.value.classList.remove(SORTABLE_LIST_CLASS_NAMES.idle);
    draggedItem.value.classList.add(SORTABLE_LIST_CLASS_NAMES.draggable);

    const top = rect.top - (containerRect?.top || 0);
    const left = rect.left - (containerRect?.left || 0);

    Object.assign(draggedItem.value.style, {
      left: `${left}px`,
      position: 'absolute',
      top: `${top}px`,
      width: `${rect.width}px`,
    });
  }

  // Marks items that are initially above the dragged item.
  function markItemsAboveDraggedItem() {
    if (!draggedItem.value) {
      return;
    }

    const draggedIndex = getSortableListItems().indexOf(draggedItem.value);

    getIdleSortableItems().forEach((item, index) => {
      if (draggedIndex > index) {
        item.dataset.isAbove = '';
      }
    });
  }

  // Moves the dragged item and updates idle item positions smoothly via RAF.
  function onPointerMove(event: MouseEvent | TouchEvent) {
    if (!draggedItem.value) {
      return;
    }

    event.preventDefault();

    const clientY =
      getPointerEventPosition(event)?.clientY || dragState.pointerStartY;
    dragState.lastPointerY = clientY;

    if (!moveRafId) {
      moveRafId = requestAnimationFrame(() => {
        moveRafId = null;
        if (!draggedItem.value) return;

        draggedItem.value.style.top = `${limitDragTop(calculateItemTopInContainer(dragState.lastPointerY), dragState.containerHeight, dragState.itemHeight)}px`;
        updateIdleItemPositions();
      });
    }
  }

  // Converts a viewport clientY into a container-relative top position.
  function calculateItemTopInContainer(clientY: number) {
    const pointerToItemTopOffset =
      dragState.pointerStartY - dragState.initialItemTop;
    const itemTopInViewport = clientY - pointerToItemTopOffset;

    const dragBounds = getDragBounds(scrollableAncestor.value);
    const clampedItemTopInViewport = Math.min(
      Math.max(itemTopInViewport, dragBounds.top),
      dragBounds.bottom - dragState.itemHeight,
    );
    const scrollOffsetSinceDragStart =
      getCurrentScrollTop(scrollableAncestor.value) -
      dragState.initialScrollTop;

    return (
      clampedItemTopInViewport -
      dragState.containerTop +
      scrollOffsetSinceDragStart
    );
  }

  // Compares the dragged item's center Y to each idle item's center Y with hysteresis and GPU 3D translation.
  function updateIdleItemPositions() {
    if (!draggedItem.value) {
      return;
    }

    const draggedItemTop = Number.parseFloat(draggedItem.value.style.top) || 0;
    const draggedItemMidY = draggedItemTop + dragState.itemHeight / 2;
    const hysteresis = dragState.itemHeight * 0.12;

    getIdleSortableItems().forEach((item) => {
      const initialRect = dragState.initialItemRects.get(item);

      if (!initialRect) {
        return;
      }

      const idleItemTopInContainer = initialRect.top - dragState.containerTop;
      const idleItemMidY = idleItemTopInContainer + initialRect.height / 2;
      const isAbove = isItemInitiallyAbove(item);
      const isShifted = item.dataset.isShifted !== undefined;

      let shouldShift = false;
      if (isAbove) {
        shouldShift = isShifted
          ? draggedItemMidY <= idleItemMidY + hysteresis
          : draggedItemMidY <= idleItemMidY - hysteresis;
      } else {
        shouldShift = isShifted
          ? draggedItemMidY >= idleItemMidY - hysteresis
          : draggedItemMidY >= idleItemMidY + hysteresis;
      }

      if (shouldShift) {
        item.dataset.isShifted = '';
        const direction = isAbove ? 1 : -1;
        item.style.transform = `translate3d(0, ${direction * dragState.itemHeight}px, 0)`;
      } else {
        delete item.dataset.isShifted;
        item.style.transform = 'translate3d(0, 0, 0)';
      }
    });
  }

  function setItemTransitions(itemList: HTMLElement[], enabled: boolean) {
    itemList.forEach((item) => {
      item.style.transition = enabled ? '' : 'none';
    });
  }

  function performAutoScroll() {
    if (!draggedItem.value) {
      return;
    }

    const rawScrollSpeed = getAutoScrollSpeed(
      dragState.lastPointerY,
      resolveListContainer(),
    );
    const speed =
      rawScrollSpeed > 0
        ? Math.ceil(rawScrollSpeed)
        : Math.floor(rawScrollSpeed);

    if (speed !== 0) {
      if (!dragState.isAutoScrolling) {
        dragState.isAutoScrolling = true;
        setItemTransitions(getIdleSortableItems(), false);
      }

      const scrollTopBefore = getCurrentScrollTop(scrollableAncestor.value);
      scrollContainerBy(scrollableAncestor.value, speed);
      const scrollTopAfter = getCurrentScrollTop(scrollableAncestor.value);
      const scrollDelta = scrollTopAfter - scrollTopBefore;

      if (scrollDelta !== 0) {
        const currentItemTop =
          Number.parseFloat(draggedItem.value.style.top) || 0;
        draggedItem.value.style.top = `${limitDragTop(currentItemTop + scrollDelta, dragState.containerHeight, dragState.itemHeight)}px`;
        updateIdleItemPositions();
      }
    } else if (dragState.isAutoScrolling) {
      dragState.isAutoScrolling = false;
      setItemTransitions(getIdleSortableItems(), true);
    }

    animationFrameId.value = requestAnimationFrame(performAutoScroll);
  }

  function stopAutoScroll() {
    if (animationFrameId.value) {
      cancelAnimationFrame(animationFrameId.value);
      animationFrameId.value = null;
    }

    if (dragState.isAutoScrolling) {
      dragState.isAutoScrolling = false;
      setItemTransitions(getIdleSortableItems(), true);
    }
  }

  function getReorderTargetIndices() {
    const sortableListItems = getSortableListItems();

    if (!draggedItem.value) {
      return {
        fromIndex: -1,
        toIndex: -1,
      };
    }

    const reorderedItems: (HTMLElement | undefined)[] = [];

    sortableListItems.forEach((item, index) => {
      if (item === draggedItem.value) {
        return;
      }

      if (!isItemShifted(item)) {
        reorderedItems[index] = item;
        return;
      }

      const shiftedIndex = isItemInitiallyAbove(item) ? index + 1 : index - 1;
      reorderedItems[shiftedIndex] = item;
    });

    let toIndex = -1;

    for (let index = 0; index < sortableListItems.length; index++) {
      if (reorderedItems[index] === undefined) {
        toIndex = index;
        break;
      }
    }

    return {
      fromIndex: sortableListItems.indexOf(draggedItem.value),
      toIndex,
    };
  }

  // Ends the drag smoothly without any sudden jump or visual refresh flash.
  function onPointerUp() {
    cancelLongPress();

    if (!draggedItem.value) {
      return;
    }

    if (moveRafId) {
      cancelAnimationFrame(moveRafId);
      moveRafId = null;
    }

    const { fromIndex, toIndex } = getReorderTargetIndices();
    const sortableListItems = getSortableListItems();

    if (toIndex !== -1 && toIndex !== fromIndex) {
      onReorder?.(fromIndex, toIndex);

      nextTick(() => {
        setItemTransitions(sortableListItems, false);
        cleanupDragSession();
        setDraggingState(false);
        nextTick(() => setItemTransitions(getSortableListItems(), true));
      });
    } else {
      setItemTransitions(sortableListItems, false);
      cleanupDragSession();
      setDraggingState(false);
      nextTick(() => setItemTransitions(sortableListItems, true));
    }
  }

  function resetDraggedItem() {
    if (!draggedItem.value) {
      return;
    }

    Object.assign(draggedItem.value.style, {
      left: '',
      position: '',
      top: '',
      transform: '',
      width: '',
    });

    draggedItem.value.classList.remove(SORTABLE_LIST_CLASS_NAMES.draggable);
    draggedItem.value.classList.add(SORTABLE_LIST_CLASS_NAMES.idle);

    spacerElement.value?.remove();
    spacerElement.value = null;
    draggedItem.value = null;
  }

  function resetIdleItems() {
    getIdleSortableItems().forEach((item) => {
      delete item.dataset.isAbove;
      delete item.dataset.isShifted;
      item.style.transform = '';
    });
  }

  function resetDragState() {
    Object.assign(dragState, createInitialDragState());
  }

  function cleanupDragSession() {
    cancelLongPress();
    stopAutoScroll();
    if (moveRafId) {
      cancelAnimationFrame(moveRafId);
      moveRafId = null;
    }
    resetIdleItems();
    resetDraggedItem();

    items.value = [];
    scrollableAncestor.value = null;

    setDocumentDraggingStyles(false);
    dragAbortController.value?.abort();
    dragAbortController.value = null;
    resetDragState();
  }

  function cleanupSortableInteractions() {
    cleanupDragSession();
    listenerAbortController.value?.abort();
    listenerAbortController.value = null;
    listMutationObserver?.disconnect();
    listMutationObserver = null;
  }

  watch(
    () => listContainerRef.value,
    () => {
      nextTick(() => {
        setupSortableInteractions();
      });
    },
  );

  onBeforeUnmount(() => {
    cleanupSortableInteractions();
  });
}
