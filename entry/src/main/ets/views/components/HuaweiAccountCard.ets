import { common } from '@kit.AbilityKit';
import {
  LoginWithHuaweiIDButton,
  loginComponentManager
} from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  HuaweiAccountPhase,
  HuaweiAccountSnapshot
} from '../../model/SyncModels';
import { HuaweiAccountService } from '../../services/HuaweiAccountService';
import { contentLightEffect, planeLightEffect } from './ImmersiveCanvas';

const EMPTY_ACCOUNT: HuaweiAccountSnapshot = {
  phase: HuaweiAccountPhase.SIGNED_OUT,
  unionId: '',
  openId: '',
  detail: ''
};
const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'HuaweiAccount';

@Component
export struct HuaweiAccountCard {
  @Prop account: HuaweiAccountSnapshot = EMPTY_ACCOUNT;
  journeyCaption: string = '';
  onAccountChange: (snapshot: HuaweiAccountSnapshot) => void =
    (snapshot: HuaweiAccountSnapshot) => {};

  private loginController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController();

  aboutToAppear(): void {
    this.loginController.onClickLoginWithHuaweiIDButton(
      (error: BusinessError, credential: loginComponentManager.HuaweiIDCredential): void => {
        if (error !== undefined && error !== null) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, 'Huawei ID sign-in failed code=%{public}d', error.code);
          this.onAccountChange(HuaweiAccountService.fromLoginError(error));
          return;
        }
        const context: common.Context = this.getUIContext().getHostContext() as common.Context;
        this.onAccountChange(HuaweiAccountService.acceptCredential(
          context, credential.unionID, credential.openID));
      });
  }

  private canLogin(): boolean {
    return this.account.phase === HuaweiAccountPhase.SIGNED_OUT ||
      this.account.phase === HuaweiAccountPhase.ERROR;
  }

  private issueText(): ResourceStr {
    if (this.account.detail === 'client-id-missing') {
      return $r('app.string.huawei_account_client_id_missing');
    }
    if (this.account.detail === '801') {
      return $r('app.string.huawei_account_device_unsupported');
    }
    if (this.account.detail === '1001500001') {
      return $r('app.string.huawei_account_fingerprint_error');
    }
    if (this.account.detail === '401' || this.account.detail === '1001500003' ||
      this.account.detail === '1001502002' || this.account.detail === '1001502003' ||
      this.account.detail === '1001502014') {
      return $r('app.string.huawei_account_authorization_error');
    }
    if (this.account.detail === '1001502005') {
      return $r('app.string.huawei_account_network_error');
    }
    if (this.account.detail === '1001500004' || this.account.detail === '1001500005') {
      return $r('app.string.huawei_account_restricted');
    }
    return $r('app.string.huawei_account_service_error');
  }

  private hasNumericDetail(): boolean {
    return this.account.detail.length > 0 && Number.isFinite(Number(this.account.detail));
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 16 }) {
        Stack() {
          if (this.account.phase === HuaweiAccountPhase.CHECKING) {
            LoadingProgress()
              .width(26)
              .height(26)
              .color($r('app.color.accent'))
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
              .fontSize(34)
              .fontColor([$r('app.color.accent')])
          }
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.accent_soft'))
        .visualEffect(contentLightEffect())

        Column({ space: 5 }) {
          this.accountStatus()
          Text(this.journeyCaption)
            .fontSize(14)
            .fontColor($r('app.color.ink_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (this.canLogin()) {
        LoginWithHuaweiIDButton({
          params: {
            style: loginComponentManager.Style.BUTTON_BLACK,
            borderRadius: 14,
            iconRadius: 18,
            supportDarkMode: true,
            loginType: loginComponentManager.LoginType.ID,
            textAndIconStyle: true
          },
          controller: this.loginController
        })
          .width('100%')
          .height(48)
      }

      if (this.account.phase === HuaweiAccountPhase.NEEDS_CONFIGURATION ||
        this.account.phase === HuaweiAccountPhase.ERROR) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize(15)
            .fontColor([this.account.phase === HuaweiAccountPhase.NEEDS_CONFIGURATION ?
              $r('app.color.ink_muted') : $r('app.color.danger')])
          Text(this.issueText())
            .layoutWeight(1)
            .fontSize(13)
            .lineHeight(19)
            .fontColor($r('app.color.ink_muted'))
        }
        .width('100%')

        if (this.hasNumericDetail()) {
          Text($r('app.string.huawei_account_error_code', this.account.detail))
            .width('100%')
            .padding({ left: 23 })
            .fontSize(11)
            .fontColor($r('app.color.ink_muted'))
        }
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane_strong'), saturation: 1.06 })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
  }

  @Builder
  private accountStatus() {
    if (this.account.phase === HuaweiAccountPhase.SIGNED_IN) {
      Text($r('app.string.huawei_account_signed_in'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    } else if (this.account.phase === HuaweiAccountPhase.CHECKING) {
      Text($r('app.string.huawei_account_checking'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    } else if (this.account.phase === HuaweiAccountPhase.NEEDS_CONFIGURATION) {
      Text($r('app.string.huawei_account_configuration_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    } else if (this.account.phase === HuaweiAccountPhase.ERROR) {
      Text($r('app.string.huawei_account_error_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    } else {
      Text($r('app.string.huawei_account_signed_out'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
    }
  }
}
