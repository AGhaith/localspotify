<script setup lang="ts">
import PreloadImage from '@/components/media/PreloadImage.vue';
import ButtonLink from '@/components/ui/ButtonLink.vue';

const {
  playFromQueue,
  removeFromQueue,
  reorderQueueTrack,
} = useAudioPlayer();
const { currentQueueIndex, currentTrack, hasCurrentTrack, queueList, toggleQueueList } = useQueue();

const sortableListContainerRef = useTemplateRef('sortableListContainerRef');

useSortableList({
  listContainerRef: sortableListContainerRef,
  onReorder: (fromIndex: number, toIndex: number) => {
    reorderQueueTrack(fromIndex, toIndex);
  },
});

function getArtistName(track: PlayableTrack): string {
  if ('artists' in track && track.artists?.length) {
    return track.artists.map((a) => a.name).join(', ');
  }
  if ('author' in track && track.author) {
    return track.author;
  }
  if ('artist' in track && track.artist) {
    return track.artist;
  }
  return 'Unknown Artist';
}
</script>

<template>
  <section :class="['queueWrapper', $style.queuePage]">
    <div :class="$style.container">
      <!-- Top Bar -->
      <div :class="$style.headerBar">
        <ButtonLink
          ref="closeQueueList"
          :class="$style.closeButton"
          :icon="ICONS.queueClose"
          iconWeight="bold"
          title="Close queue list"
          @click="toggleQueueList"
        >
          Close
        </ButtonLink>

        <h2 :class="$style.headerTitle">Queue</h2>

        <div :class="$style.headerSpacer" />
      </div>

      <!-- Empty State -->
      <div v-if="!queueList.length" :class="$style.emptyState">
        <p :class="$style.emptyText">Queue is empty</p>
      </div>

      <div v-else :class="$style.content">
        <!-- Now Playing Section -->
        <div v-if="hasCurrentTrack" :class="$style.section">
          <h3 :class="$style.sectionHeading">Now playing</h3>
          <div :class="$style.nowPlayingRow">
            <div :class="$style.coverWrapper">
              <PreloadImage
                :class="$style.coverImage"
                :image="currentTrack.image"
              />
            </div>

            <div :class="$style.trackInfo">
              <p :class="$style.nowPlayingTitle">
                {{ currentTrack.name }}
              </p>
              <p :class="$style.artistName">
                {{ getArtistName(currentTrack) }}
              </p>
            </div>
          </div>
        </div>

        <!-- Next in Queue Section -->
        <div :class="$style.section">
          <h3 :class="$style.sectionHeading">Next in queue</h3>

          <div
            ref="sortableListContainerRef"
            class="sortableListContainer"
            :class="$style.trackList"
          >
            <div
              v-for="(track, index) in queueList"
              :key="`${track.id}-${index}`"
              :class="[
                'sortableItem',
                'sortableItemIdle',
                $style.trackRow,
                {
                  [$style.activeTrackRow]: index === currentQueueIndex,
                },
              ]"
              @click="playFromQueue(index)"
            >
              <!-- Track Thumbnail -->
              <div :class="$style.coverWrapper">
                <PreloadImage
                  :class="$style.coverImage"
                  :image="track.image"
                />
              </div>

              <!-- Song Name & Artist Name (Strictly Two Lines) -->
              <div :class="$style.trackInfo">
                <p
                  :class="[
                    index === currentQueueIndex
                      ? $style.nowPlayingTitle
                      : $style.songName,
                  ]"
                >
                  {{ track.name }}
                </p>
                <p :class="$style.artistName">
                  {{ getArtistName(track) }}
                </p>
              </div>

              <!-- Actions: Remove & Drag Handle -->
              <div :class="$style.actions" @click.stop>
                <button
                  type="button"
                  :class="$style.removeBtn"
                  title="Remove from queue"
                  @click="removeFromQueue(index)"
                >
                  <PhX size="18" />
                </button>

                <div
                  :class="['sortableDragHandle', $style.dragHandle]"
                  title="Drag to reorder"
                >
                  <PhList size="20" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style module>
.queuePage {
  background-color: #000000 !important;
  color: #ffffff;
  padding: 0 0 80px;
}

.container {
  max-width: 580px;
  margin: 0 auto;
  padding: 16px 18px;
}

.headerBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
}

.closeButton {
  font-size: 0.95rem;
  font-weight: 700;
  color: #e4e4e7 !important;
}

.headerTitle {
  font-size: 1.15rem;
  font-weight: 800;
  letter-spacing: -0.01em;
  color: #ffffff;
  margin: 0;
}

.headerSpacer {
  width: 48px;
}

.emptyState {
  padding: 60px 0;
  text-align: center;
}

.emptyText {
  font-size: 1rem;
  color: #71717a;
}

.content {
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.section {
  display: flex;
  flex-direction: column;
}

.sectionHeading {
  font-size: 1.15rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: #ffffff;
  margin: 0 0 12px 2px;
}

.trackList {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.nowPlayingRow,
.trackRow {
  position: relative;
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 6px 8px;
  background: transparent;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  user-select: none;
  transition: transform 0.28s cubic-bezier(0.2, 0.9, 0.3, 1), background-color 0.12s ease;

  &:hover {
    background-color: rgba(255, 255, 255, 0.07);
  }

  &:active {
    background-color: rgba(255, 255, 255, 0.12);
  }
}

.activeTrackRow {
  background-color: rgba(34, 197, 94, 0.08);
}

.coverWrapper {
  position: relative;
  flex-shrink: 0;
  width: 48px;
  height: 48px;
  border-radius: 4px;
  overflow: hidden;
  background-color: #27272a;
}

.coverImage {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.trackInfo {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 3px;
  min-width: 0;
  overflow: hidden;
}

.nowPlayingTitle {
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.25;
  color: #22c55e;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin: 0;
}

.songName {
  font-size: 0.95rem;
  font-weight: 600;
  line-height: 1.25;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin: 0;
}

.artistName {
  font-size: 0.82rem;
  font-weight: 400;
  line-height: 1.25;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin: 0;
}

.actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
}

.removeBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  color: #71717a;
  background: transparent;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: color 0.15s, background-color 0.15s;

  &:hover {
    color: #ef4444;
    background-color: rgba(239, 68, 68, 0.15);
  }
}

.dragHandle {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  color: #71717a;
  border-radius: 4px;
  cursor: grab;
  touch-action: none;
  transition: color 0.15s;

  &:hover {
    color: #ffffff;
  }

  &:active {
    cursor: grabbing;
    color: #22c55e;
  }
}
</style>
