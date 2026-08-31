import { bundleManager, common } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  HuaweiAccountPhase,
  HuaweiAccountSnapshot
} from '../model/SyncModels';

const STORE_NAME: string = 'kotoba_huawei_identity';
const KEY_UNION_ID: string = 'union_id';
const KEY_OPEN_ID: string = 'open_id';
const METADATA_CLIENT_ID: string = 'client_id';
const DETAIL_CLIENT_ID_MISSING: string = 'client-id-missing';

export class HuaweiAccountService {
  static signedOut(detail: string = ''): HuaweiAccountSnapshot {
    return {
      phase: HuaweiAccountPhase.SIGNED_OUT,
      unionId: '',
      openId: '',
      detail: detail
    };
  }

  static checking(): HuaweiAccountSnapshot {
    return {
      phase: HuaweiAccountPhase.CHECKING,
      unionId: '',
      openId: '',
      detail: ''
    };
  }

  static acceptCredential(context: common.Context, unionId: string, openId: string): HuaweiAccountSnapshot {
    if (unionId.length === 0 || openId.length === 0) {
      return HuaweiAccountService.errorSnapshot('empty-credential');
    }
    try {
      const store: preferences.Preferences = HuaweiAccountService.store(context);
      store.putSync(KEY_UNION_ID, unionId);
      store.putSync(KEY_OPEN_ID, openId);
      store.flush();
      return HuaweiAccountService.signedIn(unionId, openId);
    } catch (error) {
      return HuaweiAccountService.errorSnapshot('identity-cache-failed');
    }
  }

  static async refresh(context: common.Context): Promise<HuaweiAccountSnapshot> {
    const configurationIssue: string = HuaweiAccountService.configurationIssue();
    if (configurationIssue.length > 0) {
      return HuaweiAccountService.configurationSnapshot(configurationIssue);
    }

    let unionId: string = '';
    let openId: string = '';
    try {
      const store: preferences.Preferences = HuaweiAccountService.store(context);
      unionId = store.getSync(KEY_UNION_ID, '') as string;
      openId = store.getSync(KEY_OPEN_ID, '') as string;
    } catch (error) {
      return HuaweiAccountService.errorSnapshot('identity-cache-failed');
    }
    if (unionId.length === 0 || openId.length === 0) {
      return HuaweiAccountService.signedOut();
    }

    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const result: authentication.StateResult = await provider.getHuaweiIDState({
        idType: authentication.IdType.UNION_ID,
        idValue: unionId
      });
      if (result.state === authentication.State.AUTHORIZED) {
        return HuaweiAccountService.signedIn(unionId, openId);
      }
      HuaweiAccountService.clearCachedIdentity(context);
      return HuaweiAccountService.signedOut();
    } catch (error) {
      return HuaweiAccountService.fromError(error as BusinessError, unionId, openId);
    }
  }

  static fromLoginError(error: BusinessError): HuaweiAccountSnapshot {
    if (error.code === 1001500002 || error.code === 1001502001 || error.code === 1001502012) {
      return HuaweiAccountService.signedOut(error.code.toString());
    }
    return HuaweiAccountService.fromError(error, '', '');
  }

  private static configurationIssue(): string {
    try {
      const flags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA;
      const bundleInfo: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(flags);
      for (let moduleIndex: number = 0; moduleIndex < bundleInfo.hapModulesInfo.length; moduleIndex++) {
        const metadata: bundleManager.Metadata[] = bundleInfo.hapModulesInfo[moduleIndex].metadata;
        for (let metadataIndex: number = 0; metadataIndex < metadata.length; metadataIndex++) {
          if (metadata[metadataIndex].name === METADATA_CLIENT_ID &&
            metadata[metadataIndex].value.trim().length > 0) {
            return '';
          }
        }
      }
      return DETAIL_CLIENT_ID_MISSING;
    } catch (error) {
      // If bundle metadata cannot be inspected on this device, let Account Kit return its native error.
      return '';
    }
  }

  private static signedIn(unionId: string, openId: string): HuaweiAccountSnapshot {
    return {
      phase: HuaweiAccountPhase.SIGNED_IN,
      unionId: unionId,
      openId: openId,
      detail: ''
    };
  }

  private static errorSnapshot(detail: string): HuaweiAccountSnapshot {
    return {
      phase: HuaweiAccountPhase.ERROR,
      unionId: '',
      openId: '',
      detail: detail
    };
  }

  private static configurationSnapshot(detail: string): HuaweiAccountSnapshot {
    return {
      phase: HuaweiAccountPhase.NEEDS_CONFIGURATION,
      unionId: '',
      openId: '',
      detail: detail
    };
  }

  private static fromError(error: BusinessError, unionId: string,
    openId: string): HuaweiAccountSnapshot {
    const detail: string = error.code === undefined ? 'unknown' : error.code.toString();
    if (error.code === 1001502001 || error.code === 1001502012) {
      return HuaweiAccountService.signedOut(detail);
    }
    const needsConfiguration: boolean = error.code === 401 || error.code === 801 ||
      error.code === 1001500001 || error.code === 1001500003 || error.code === 1001502002 ||
      error.code === 1001502003 || error.code === 1001502014;
    return {
      phase: needsConfiguration ? HuaweiAccountPhase.NEEDS_CONFIGURATION : HuaweiAccountPhase.ERROR,
      unionId: unionId,
      openId: openId,
      detail: detail
    };
  }

  private static store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE_NAME });
  }

  private static clearCachedIdentity(context: common.Context): void {
    try {
      const store: preferences.Preferences = HuaweiAccountService.store(context);
      store.deleteSync(KEY_UNION_ID);
      store.deleteSync(KEY_OPEN_ID);
      store.flush();
    } catch (error) {
      return;
    }
  }
}
