import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { RealtimeCredentials } from '../model/RealtimeVoiceModels';

/** App-private, device-local credentials; deliberately excluded from learning sync. */
export class RealtimeVoicePreferences {
  static read(context: common.Context): RealtimeCredentials {
    const store = preferences.getPreferencesSync(context, { name: 'kotoba_podcast' });
    // Legacy Access Tokens are not interchangeable with the new API Key.
    return { apiKey: store.getSync('api_key', '') as string };
  }

  static async save(context: common.Context, credentials: RealtimeCredentials): Promise<void> {
    const store = preferences.getPreferencesSync(context, { name: 'kotoba_podcast' });
    store.putSync('api_key', credentials.apiKey.trim());
    store.deleteSync('app_id');
    store.deleteSync('access_key');
    await store.flush();
  }
}
