import { common, WantAgent, wantAgent } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { MusicTrack } from '../model/ContentModels';
import {
  emptyMusicPlaybackSnapshot,
  MusicPlaybackListener,
  MusicPlaybackPhase,
  MusicPlaybackSnapshot
} from '../model/MusicPlaybackModels';
import { LearningPreferences } from './LearningPreferences';
import { LearningSyncCoordinator } from './LearningSyncCoordinator';
import { musicRendererInfo, PlayerStateMachine } from './MusicPlaybackStateMachine';

const POSITION_PERSIST_INTERVAL_MS: number = 3000;
const POSITION_SYNC_INTERVAL_MS: number = 15000;
const POSITION_END_TOLERANCE_MS: number = 1500;
const DEFAULT_SKIP_MS: number = 15000;

/**
 * App-wide music engine. AVPlayer and AVSession deliberately live outside page
 * components so playback is not destroyed when the user changes tabs.
 */
export class MusicPlaybackService {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static tracks: MusicTrack[] = [];
  private static player: media.AVPlayer | undefined = undefined;
  private static session: avSession.AVSession | undefined = undefined;
  private static sessionCreating: boolean = false;
  private static listeners: MusicPlaybackListener[] = [];
  private static playback: MusicPlaybackSnapshot = emptyMusicPlaybackSnapshot();
  private static activeRawPath: string = '';
  private static sourceToken: number = 0;
  private static autoplayOnPrepared: boolean = false;
  private static backgroundTaskId: number = -1;
  private static backgroundTaskStarting: boolean = false;
  private static lastPersistedPosition: number = 0;
  private static lastSyncedPosition: number = 0;
  private static lastSessionUpdateAt: number = 0;
  // AVPlayer's transitions are asynchronous and only legal from specific
  // states. The machine owns that bookkeeping so callers await a state instead
  // of assuming an operation already moved the player into it.
  private static machine: PlayerStateMachine = new PlayerStateMachine();
  // Serialises transport commands. AVPlayer rejects play()/pause() issued from
  // a state it has not reached yet, and stateChange is asynchronous, so a fast
  // double tap can otherwise fire pause() twice — the second one lands in
  // paused and throws, which reads as the button doing nothing.
  private static commandInFlight: boolean = false;

  static initialize(context: common.Context, tracks: MusicTrack[]): void {
    MusicPlaybackService.context = context as common.UIAbilityContext;
    MusicPlaybackService.tracks = tracks.slice();
    if (MusicPlaybackService.player === undefined &&
      MusicPlaybackService.playback.phase === MusicPlaybackPhase.IDLE && tracks.length > 0) {
      const storedIndex: number = LearningPreferences.musicIndex(context);
      if (storedIndex >= 0 && storedIndex < tracks.length) {
        const track: MusicTrack = tracks[storedIndex];
        const positionMs: number = LearningPreferences.musicPosition(context, track.id);
        MusicPlaybackService.playback = {
          phase: MusicPlaybackPhase.IDLE,
          trackIndex: storedIndex,
          trackId: track.id,
          positionMs: positionMs,
          durationMs: track.durationMs,
          error: ''
        };
      }
    }
    MusicPlaybackService.notify();
    MusicPlaybackService.ensureSession();
  }

  static subscribe(listener: MusicPlaybackListener): void {
    if (MusicPlaybackService.listeners.indexOf(listener) < 0) {
      MusicPlaybackService.listeners.push(listener);
    }
    listener(MusicPlaybackService.snapshot());
  }

  static unsubscribe(listener: MusicPlaybackListener): void {
    const index: number = MusicPlaybackService.listeners.indexOf(listener);
    if (index >= 0) {
      MusicPlaybackService.listeners.splice(index, 1);
    }
  }

  static snapshot(): MusicPlaybackSnapshot {
    return {
      phase: MusicPlaybackService.playback.phase,
      trackIndex: MusicPlaybackService.playback.trackIndex,
      trackId: MusicPlaybackService.playback.trackId,
      positionMs: MusicPlaybackService.playback.positionMs,
      durationMs: MusicPlaybackService.playback.durationMs,
      error: MusicPlaybackService.playback.error
    };
  }

  static async prepareTrack(index: number): Promise<void> {
    await MusicPlaybackService.selectTrack(index, false);
  }

  static async playTrack(index: number): Promise<void> {
    await MusicPlaybackService.selectTrack(index, true);
  }

  static async toggle(): Promise<void> {
    if (MusicPlaybackService.playback.phase === MusicPlaybackPhase.PLAYING) {
      await MusicPlaybackService.pause();
    } else {
      await MusicPlaybackService.play();
    }
  }

  /**
   * Whether the player is in one of the states where play() and seek() are
   * legal: prepared/playing/paused/completed. Calling either from idle,
   * initialized or stopped is rejected with 5400102.
   */
  private static canOperate(): boolean {
    const state: string = MusicPlaybackService.machine.state;
    return state === 'prepared' || state === 'playing' || state === 'paused' || state === 'completed';
  }

  static async play(): Promise<void> {
    const index: number = MusicPlaybackService.playback.trackIndex >= 0 ?
      MusicPlaybackService.playback.trackIndex : 0;
    if (index < 0 || index >= MusicPlaybackService.tracks.length) {
      return;
    }
    const player: media.AVPlayer | undefined = MusicPlaybackService.player;
    if (player === undefined || MusicPlaybackService.playback.trackId !== MusicPlaybackService.tracks[index].id ||
      MusicPlaybackService.playback.phase === MusicPlaybackPhase.IDLE ||
      MusicPlaybackService.playback.phase === MusicPlaybackPhase.ERROR) {
      await MusicPlaybackService.selectTrack(index, true);
      return;
    }
    if (MusicPlaybackService.playback.phase === MusicPlaybackPhase.LOADING) {
      MusicPlaybackService.autoplayOnPrepared = true;
      return;
    }
    try {
      // A stopped player has no prepared source; bring it back before playing.
      if (!MusicPlaybackService.canOperate()) {
        await player.prepare();
        const prepared: boolean = await MusicPlaybackService.machine.waitFor('prepared', () => false);
        if (!prepared) {
          MusicPlaybackService.fail(new Error('reprepare failed'));
          return;
        }
      }
      if (MusicPlaybackService.machine.state === 'playing') {
        return;
      }
      MusicPlaybackService.commandInFlight = true;
      if (MusicPlaybackService.playback.phase === MusicPlaybackPhase.COMPLETED) {
        player.seek(0, media.SeekMode.SEEK_PREV_SYNC);
        MusicPlaybackService.updatePosition(0, true);
      }
      await player.play();
    } catch (error) {
      MusicPlaybackService.fail(error);
    } finally {
      MusicPlaybackService.commandInFlight = false;
    }
  }

  static async pause(): Promise<void> {
    const player: media.AVPlayer | undefined = MusicPlaybackService.player;
    if (player === undefined || MusicPlaybackService.commandInFlight) {
      return;
    }
    // pause() is only legal from playing. The app-level phase is updated from
    // the asynchronous stateChange event, so it can still read PLAYING after
    // pause() has already been accepted; the machine's state is the authority.
    if (MusicPlaybackService.machine.state !== 'playing') {
      return;
    }
    MusicPlaybackService.commandInFlight = true;
    try {
      await player.pause();
      MusicPlaybackService.persistPosition(true);
    } catch (error) {
      MusicPlaybackService.fail(error);
    } finally {
      MusicPlaybackService.commandInFlight = false;
    }
  }

  static async next(): Promise<void> {
    await MusicPlaybackService.playAdjacent(1);
  }

  static async previous(): Promise<void> {
    if (MusicPlaybackService.playback.positionMs > 5000) {
      MusicPlaybackService.seek(0);
      return;
    }
    await MusicPlaybackService.playAdjacent(-1);
  }

  static seek(positionMs: number): void {
    const player: media.AVPlayer | undefined = MusicPlaybackService.player;
    if (player === undefined || !MusicPlaybackService.canOperate()) {
      return;
    }
    const upper: number = Math.max(0, MusicPlaybackService.playback.durationMs);
    const target: number = Math.max(0, Math.min(Math.floor(positionMs), upper));
    try {
      player.seek(target, media.SeekMode.SEEK_CLOSEST);
      MusicPlaybackService.updatePosition(target, true);
    } catch (error) {
      MusicPlaybackService.fail(error);
    }
  }

  static seekRelative(deltaMs: number): void {
    MusicPlaybackService.seek(MusicPlaybackService.playback.positionMs + deltaMs);
  }

  static async release(): Promise<void> {
    MusicPlaybackService.sourceToken++;
    // Wake anything awaiting a transition; the player is going away.
    MusicPlaybackService.machine.cancelAll();
    MusicPlaybackService.commandInFlight = false;
    MusicPlaybackService.persistPosition(true);
    await MusicPlaybackService.stopBackgroundTask();
    if (MusicPlaybackService.player !== undefined) {
      try {
        await MusicPlaybackService.player.release();
      } catch (error) {
        // The player may already be released by the media service.
      }
      MusicPlaybackService.player = undefined;
    }
    await MusicPlaybackService.closeRawFile();
    if (MusicPlaybackService.session !== undefined) {
      try {
        await MusicPlaybackService.session.deactivate();
        await MusicPlaybackService.session.destroy();
      } catch (error) {
        // Session cleanup should never block ability teardown.
      }
      MusicPlaybackService.session = undefined;
    }
    MusicPlaybackService.playback = emptyMusicPlaybackSnapshot();
    MusicPlaybackService.notify();
  }

  private static async selectTrack(index: number, autoplay: boolean): Promise<void> {
    if (index < 0 || index >= MusicPlaybackService.tracks.length || MusicPlaybackService.context === undefined) {
      return;
    }
    const track: MusicTrack = MusicPlaybackService.tracks[index];
    const existing: media.AVPlayer | undefined = MusicPlaybackService.player;
    if (existing !== undefined && MusicPlaybackService.playback.trackId === track.id &&
      MusicPlaybackService.playback.phase !== MusicPlaybackPhase.IDLE &&
      MusicPlaybackService.playback.phase !== MusicPlaybackPhase.ERROR) {
      if (autoplay) {
        await MusicPlaybackService.play();
      }
      return;
    }

    const token: number = ++MusicPlaybackService.sourceToken;
    MusicPlaybackService.autoplayOnPrepared = autoplay;
    MusicPlaybackService.persistPosition(true);
    MusicPlaybackService.playback = {
      phase: MusicPlaybackPhase.LOADING,
      trackIndex: index,
      trackId: track.id,
      positionMs: 0,
      durationMs: track.durationMs,
      error: ''
    };
    MusicPlaybackService.lastPersistedPosition = 0;
    MusicPlaybackService.lastSyncedPosition = 0;
    MusicPlaybackService.notify();
    LearningPreferences.saveMusicIndex(MusicPlaybackService.context, index);
    LearningSyncCoordinator.saveMusicProgress(MusicPlaybackService.context, index);

    try {
      const player: media.AVPlayer = await MusicPlaybackService.ensurePlayer();
      if (token !== MusicPlaybackService.sourceToken) {
        return;
      }

      // fdSrc is only accepted in idle, so get there first and wait for the
      // transition to actually land before touching the player.
      const reset: boolean = await MusicPlaybackService.machine.resetIfNeeded(player);
      if (token !== MusicPlaybackService.sourceToken) {
        return;
      }
      if (!reset) {
        throw new Error('player reset failed');
      }

      await MusicPlaybackService.closeRawFile();
      if (token !== MusicPlaybackService.sourceToken) {
        return;
      }

      const descriptor = await MusicPlaybackService.context.resourceManager.getRawFd(track.audioSource);
      if (token !== MusicPlaybackService.sourceToken) {
        await MusicPlaybackService.context.resourceManager.closeRawFd(track.audioSource);
        return;
      }
      MusicPlaybackService.activeRawPath = track.audioSource;
      player.fdSrc = {
        fd: descriptor.fd,
        offset: descriptor.offset,
        length: descriptor.length
      };

      // Setting the source moves the player to initialized asynchronously.
      // prepare() is illegal until that happens — this wait is what prevents
      // the 5400102 "Operate Not Permit" failure.
      const initialized: boolean = await MusicPlaybackService.machine.waitFor('initialized',
        () => token !== MusicPlaybackService.sourceToken);
      if (token !== MusicPlaybackService.sourceToken) {
        return;
      }
      if (!initialized) {
        throw new Error('source not initialized');
      }

      // audioRendererInfo is only accepted in initialized, before prepare().
      player.audioRendererInfo = musicRendererInfo();

      await player.prepare();
      if (token !== MusicPlaybackService.sourceToken) {
        return;
      }

      const prepared: boolean = await MusicPlaybackService.machine.waitFor('prepared',
        () => token !== MusicPlaybackService.sourceToken);
      if (token !== MusicPlaybackService.sourceToken) {
        return;
      }
      if (!prepared) {
        throw new Error('prepare did not complete');
      }

      const durationMs: number = player.duration > 0 ? player.duration : track.durationMs;
      let restoredPosition: number = LearningPreferences.musicPosition(MusicPlaybackService.context, track.id);
      if (restoredPosition >= durationMs - POSITION_END_TOLERANCE_MS) {
        restoredPosition = 0;
      }
      MusicPlaybackService.playback = {
        phase: MusicPlaybackPhase.READY,
        trackIndex: index,
        trackId: track.id,
        positionMs: restoredPosition,
        durationMs: durationMs,
        error: ''
      };
      MusicPlaybackService.lastPersistedPosition = restoredPosition;
      MusicPlaybackService.lastSyncedPosition = restoredPosition;
      if (restoredPosition > 0) {
        player.seek(restoredPosition, media.SeekMode.SEEK_CLOSEST);
      }
      MusicPlaybackService.notify();
      await MusicPlaybackService.updateSessionMetadata(track, durationMs);
      MusicPlaybackService.updateSessionState(true);
      if (MusicPlaybackService.autoplayOnPrepared) {
        await player.play();
      }
    } catch (error) {
      if (token === MusicPlaybackService.sourceToken) {
        MusicPlaybackService.fail(error);
      }
    }
  }

  private static async playAdjacent(delta: number): Promise<void> {
    if (MusicPlaybackService.tracks.length === 0) {
      return;
    }
    const current: number = MusicPlaybackService.playback.trackIndex >= 0 ?
      MusicPlaybackService.playback.trackIndex : 0;
    const nextIndex: number = (current + delta + MusicPlaybackService.tracks.length) %
      MusicPlaybackService.tracks.length;
    await MusicPlaybackService.selectTrack(nextIndex, true);
  }

  private static async ensurePlayer(): Promise<media.AVPlayer> {
    if (MusicPlaybackService.player !== undefined && MusicPlaybackService.player.state !== 'released') {
      return MusicPlaybackService.player;
    }
    const player: media.AVPlayer = await media.createAVPlayer();
    MusicPlaybackService.player = player;
    player.on('stateChange', (state: media.AVPlayerState, reason: media.StateChangeReason) => {
      // Feed the machine first: it resolves any awaiters, and the phase mapping
      // below reads the state the machine just recorded.
      MusicPlaybackService.machine.onStateChange(state);
      MusicPlaybackService.handlePlayerState(state);
    });
    player.on('timeUpdate', (positionMs: number) => {
      MusicPlaybackService.updatePosition(positionMs, false);
    });
    player.on('durationUpdate', (durationMs: number) => {
      if (durationMs > 0) {
        MusicPlaybackService.playback.durationMs = durationMs;
        MusicPlaybackService.notify();
      }
    });
    player.on('seekDone', (positionMs: number) => {
      MusicPlaybackService.updatePosition(positionMs, true);
    });
    player.on('audioInterrupt', (event: audio.InterruptEvent) => {
      MusicPlaybackService.handleAudioInterrupt(event);
    });
    player.on('audioOutputDeviceChangeWithInfo', (event: audio.AudioStreamDeviceChangeInfo) => {
      if (event.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        MusicPlaybackService.pause();
      }
    });
    player.on('error', (error: BusinessError) => {
      MusicPlaybackService.fail(error);
    });
    return player;
  }

  private static handlePlayerState(state: media.AVPlayerState): void {
    switch (state) {
      case 'initialized':
        // The source is set and prepare() is now legal. The load is still in
        // flight, so keep the phase as LOADING until prepared arrives.
        break;
      case 'prepared':
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.READY;
        break;
      case 'playing':
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.PLAYING;
        MusicPlaybackService.startBackgroundTask();
        break;
      case 'paused':
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.PAUSED;
        MusicPlaybackService.persistPosition(true);
        MusicPlaybackService.stopBackgroundTask();
        break;
      case 'completed':
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.COMPLETED;
        MusicPlaybackService.playback.positionMs = MusicPlaybackService.playback.durationMs;
        MusicPlaybackService.persistPosition(true);
        MusicPlaybackService.stopBackgroundTask();
        MusicPlaybackService.notify();
        MusicPlaybackService.updateSessionState(true);
        MusicPlaybackService.playAdjacent(1);
        return;
      case 'stopped':
        // Reached via stop(); the player is still usable but needs a new
        // prepare() before it can play again.
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.READY;
        break;
      case 'idle':
        // After reset, before a new source is assigned.
        break;
      case 'released':
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.IDLE;
        break;
      case 'error':
        MusicPlaybackService.playback.phase = MusicPlaybackPhase.ERROR;
        MusicPlaybackService.stopBackgroundTask();
        break;
      default:
        break;
    }
    MusicPlaybackService.notify();
    MusicPlaybackService.updateSessionState(true);
  }

  private static handleAudioInterrupt(event: audio.InterruptEvent): void {
    if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
      event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
      MusicPlaybackService.pause();
    } else if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME &&
      event.forceType === audio.InterruptForceType.INTERRUPT_SHARE) {
      MusicPlaybackService.play();
    }
  }

  private static updatePosition(positionMs: number, forcePersist: boolean): void {
    if (positionMs < 0 || MusicPlaybackService.playback.trackIndex < 0) {
      return;
    }
    MusicPlaybackService.playback.positionMs = positionMs;
    MusicPlaybackService.notify();
    if (forcePersist || Math.abs(positionMs - MusicPlaybackService.lastPersistedPosition) >=
      POSITION_PERSIST_INTERVAL_MS) {
      MusicPlaybackService.persistPosition(false);
    }
    if (Math.abs(positionMs - MusicPlaybackService.lastSyncedPosition) >= POSITION_SYNC_INTERVAL_MS) {
      MusicPlaybackService.syncPosition();
    }
    MusicPlaybackService.updateSessionState();
  }

  private static persistPosition(sync: boolean): void {
    if (MusicPlaybackService.context === undefined || MusicPlaybackService.playback.trackId.length === 0) {
      return;
    }
    const positionMs: number = MusicPlaybackService.playback.positionMs >=
      MusicPlaybackService.playback.durationMs - POSITION_END_TOLERANCE_MS ? 0 :
      MusicPlaybackService.playback.positionMs;
    LearningPreferences.saveMusicPosition(
      MusicPlaybackService.context, MusicPlaybackService.playback.trackId, positionMs);
    MusicPlaybackService.lastPersistedPosition = MusicPlaybackService.playback.positionMs;
    if (sync) {
      MusicPlaybackService.syncPosition();
    }
  }

  private static syncPosition(): void {
    if (MusicPlaybackService.context === undefined || MusicPlaybackService.playback.trackId.length === 0) {
      return;
    }
    const positionMs: number = MusicPlaybackService.playback.positionMs >=
      MusicPlaybackService.playback.durationMs - POSITION_END_TOLERANCE_MS ? 0 :
      MusicPlaybackService.playback.positionMs;
    LearningSyncCoordinator.saveMusicPosition(
      MusicPlaybackService.context, MusicPlaybackService.playback.trackId, positionMs);
    MusicPlaybackService.lastSyncedPosition = MusicPlaybackService.playback.positionMs;
  }

  private static notify(): void {
    const snapshot: MusicPlaybackSnapshot = MusicPlaybackService.snapshot();
    for (let index: number = 0; index < MusicPlaybackService.listeners.length; index++) {
      MusicPlaybackService.listeners[index](snapshot);
    }
  }

  private static fail(error: Object): void {
    const businessError: BusinessError = error as BusinessError;
    const standardError: Error = error as Error;
    const detail: string = businessError.code !== undefined ? businessError.code.toString() :
      (standardError.message === undefined ? 'unknown' : standardError.message);
    MusicPlaybackService.playback.phase = MusicPlaybackPhase.ERROR;
    MusicPlaybackService.playback.error = detail;
    // Drop any in-flight transition waits so a failed load cannot later resolve
    // and resurrect a stale track.
    MusicPlaybackService.machine.cancelAll();
    MusicPlaybackService.commandInFlight = false;
    MusicPlaybackService.notify();
    MusicPlaybackService.updateSessionState(true);
    MusicPlaybackService.stopBackgroundTask();
  }

  private static async ensureSession(): Promise<void> {
    if (MusicPlaybackService.session !== undefined || MusicPlaybackService.sessionCreating ||
      MusicPlaybackService.context === undefined) {
      return;
    }
    MusicPlaybackService.sessionCreating = true;
    try {
      const session: avSession.AVSession = await avSession.createAVSession(
        MusicPlaybackService.context, 'KotobaMusic', 'audio');
      MusicPlaybackService.session = session;
      session.on('play', () => MusicPlaybackService.play());
      session.on('pause', () => MusicPlaybackService.pause());
      session.on('stop', () => MusicPlaybackService.pause());
      session.on('playNext', () => MusicPlaybackService.next());
      session.on('playPrevious', () => MusicPlaybackService.previous());
      session.on('seek', (positionMs: number) => MusicPlaybackService.seek(positionMs));
      session.on('fastForward', (time?: number) =>
        MusicPlaybackService.seekRelative(time === undefined ? DEFAULT_SKIP_MS : time));
      session.on('rewind', (time?: number) =>
        MusicPlaybackService.seekRelative(-(time === undefined ? DEFAULT_SKIP_MS : time)));
      await session.activate();
      if (MusicPlaybackService.playback.trackIndex >= 0 &&
        MusicPlaybackService.playback.trackIndex < MusicPlaybackService.tracks.length) {
        await MusicPlaybackService.updateSessionMetadata(
          MusicPlaybackService.tracks[MusicPlaybackService.playback.trackIndex],
          MusicPlaybackService.playback.durationMs);
      }
      MusicPlaybackService.updateSessionState(true);
    } catch (error) {
      MusicPlaybackService.session = undefined;
    } finally {
      MusicPlaybackService.sessionCreating = false;
    }
  }

  private static async updateSessionMetadata(track: MusicTrack, durationMs: number): Promise<void> {
    await MusicPlaybackService.ensureSession();
    if (MusicPlaybackService.session === undefined || MusicPlaybackService.context === undefined) {
      return;
    }
    let imageSource: image.ImageSource | undefined = undefined;
    let artwork: image.PixelMap | undefined = undefined;
    try {
      const bytes: Uint8Array = await MusicPlaybackService.context.resourceManager.getMediaByName(track.artworkName);
      imageSource = image.createImageSource(bytes.buffer as ArrayBuffer);
      artwork = await imageSource.createPixelMap({
        desiredSize: { width: 512, height: 512 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const metadata: avSession.AVMetadata = {
        assetId: track.id,
        title: track.title,
        artist: track.artist,
        album: '言葉 · 探索',
        duration: durationMs,
        mediaImage: artwork
      };
      await MusicPlaybackService.session.setAVMetadata(metadata);
    } catch (error) {
      try {
        await MusicPlaybackService.session.setAVMetadata({
          assetId: track.id,
          title: track.title,
          artist: track.artist,
          album: '言葉 · 探索',
          duration: durationMs
        });
      } catch (metadataError) {
        // Metadata failure should not stop local playback.
      }
    } finally {
      if (artwork !== undefined) {
        try {
          await artwork.release();
        } catch (error) {
          // The media center already received its own copy.
        }
      }
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (error) {
          // Ignore decoder cleanup failures.
        }
      }
    }
  }

  private static updateSessionState(force: boolean = false): void {
    if (MusicPlaybackService.session === undefined) {
      return;
    }
    const now: number = Date.now();
    if (!force && now - MusicPlaybackService.lastSessionUpdateAt < 800) {
      return;
    }
    MusicPlaybackService.lastSessionUpdateAt = now;
    let state: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_INITIAL;
    if (MusicPlaybackService.playback.phase === MusicPlaybackPhase.LOADING ||
      MusicPlaybackService.playback.phase === MusicPlaybackPhase.READY) {
      state = avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
    } else if (MusicPlaybackService.playback.phase === MusicPlaybackPhase.PLAYING) {
      state = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    } else if (MusicPlaybackService.playback.phase === MusicPlaybackPhase.PAUSED ||
      MusicPlaybackService.playback.phase === MusicPlaybackPhase.COMPLETED) {
      state = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    }
    MusicPlaybackService.session.setAVPlaybackState({
      state: state,
      speed: MusicPlaybackService.playback.phase === MusicPlaybackPhase.PLAYING ? 1 : 0,
      position: {
        elapsedTime: MusicPlaybackService.playback.positionMs,
        updateTime: now
      },
      bufferedTime: MusicPlaybackService.playback.durationMs
    }).catch((error: Error) => {});
  }

  private static async startBackgroundTask(): Promise<void> {
    if (MusicPlaybackService.context === undefined || MusicPlaybackService.backgroundTaskId >= 0 ||
      MusicPlaybackService.backgroundTaskStarting) {
      return;
    }
    MusicPlaybackService.backgroundTaskStarting = true;
    try {
      const context: common.UIAbilityContext = MusicPlaybackService.context;
      const agent: WantAgent = await wantAgent.getWantAgent({
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 5201,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      const request: backgroundTaskManager.ContinuousTaskRequest =
        new backgroundTaskManager.ContinuousTaskRequest();
      request.backgroundTaskModes = [
        backgroundTaskManager.BackgroundTaskMode.MODE_AV_PLAYBACK_AND_RECORD
      ];
      request.backgroundTaskSubmodes = [
        backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_AVSESSION_AUDIO_PLAYBACK
      ];
      request.wantAgent = agent;
      const notification: backgroundTaskManager.ContinuousTaskNotification =
        await backgroundTaskManager.startBackgroundRunning(context, request);
      MusicPlaybackService.backgroundTaskId = notification.continuousTaskId === undefined ? -1 :
        notification.continuousTaskId;
    } catch (error) {
      MusicPlaybackService.backgroundTaskId = -1;
    } finally {
      MusicPlaybackService.backgroundTaskStarting = false;
    }
  }

  private static async stopBackgroundTask(): Promise<void> {
    if (MusicPlaybackService.context === undefined || MusicPlaybackService.backgroundTaskId < 0) {
      return;
    }
    const taskId: number = MusicPlaybackService.backgroundTaskId;
    MusicPlaybackService.backgroundTaskId = -1;
    try {
      await backgroundTaskManager.stopBackgroundRunning(MusicPlaybackService.context, taskId);
    } catch (error) {
      // The system may have already reclaimed the task.
    }
  }

  private static async closeRawFile(): Promise<void> {
    if (MusicPlaybackService.context === undefined || MusicPlaybackService.activeRawPath.length === 0) {
      return;
    }
    const path: string = MusicPlaybackService.activeRawPath;
    MusicPlaybackService.activeRawPath = '';
    try {
      await MusicPlaybackService.context.resourceManager.closeRawFd(path);
    } catch (error) {
      // Ignore an already closed resource descriptor.
    }
  }
}
