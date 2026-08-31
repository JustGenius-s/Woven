import {
  abilityAccessCtrl,
  common,
  PermissionRequestResult,
  Permissions
} from '@kit.AbilityKit';

export const DISTRIBUTED_SYNC_PERMISSION_REQUIRED: string =
  'distributed-datasync-permission-required';

const DISTRIBUTED_DATASYNC_PERMISSION: Permissions =
  'ohos.permission.DISTRIBUTED_DATASYNC';

export class DistributedSyncPermission {
  static isGranted(): boolean {
    try {
      return abilityAccessCtrl.createAtManager()
        .getSelfPermissionStatus(DISTRIBUTED_DATASYNC_PERMISSION) ===
        abilityAccessCtrl.PermissionStatus.GRANTED;
    } catch (error) {
      return false;
    }
  }

  static async ensure(context: common.UIAbilityContext, requestIfNeeded: boolean): Promise<boolean> {
    if (DistributedSyncPermission.isGranted()) {
      return true;
    }
    if (!requestIfNeeded) {
      return false;
    }

    try {
      const result: PermissionRequestResult = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, [DISTRIBUTED_DATASYNC_PERMISSION]);
      for (let index: number = 0; index < result.permissions.length; index++) {
        if (result.permissions[index] === DISTRIBUTED_DATASYNC_PERMISSION) {
          return result.authResults[index] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        }
      }
    } catch (error) {
      return false;
    }
    return false;
  }
}
