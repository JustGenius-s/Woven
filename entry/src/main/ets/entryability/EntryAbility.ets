import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { JapaneseTtsService } from '../services/JapaneseTtsService';
import { MusicPlaybackService } from '../services/MusicPlaybackService';

const DOMAIN: number = 0x4b4f;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      hilog.warn(DOMAIN, 'Kotoba', 'Unable to follow system color mode');
    }
    hilog.info(DOMAIN, 'Kotoba', 'Application created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      this.mainWindow = windowStage.getMainWindowSync();
      this.applyWindowAppearance();
      this.mainWindow.setWindowLayoutFullScreen(true)
        .then(() => this.applyWindowAppearance())
        .catch((error: Object) => {
          hilog.warn(DOMAIN, 'Kotoba', 'Unable to enable immersive window layout: %{public}s',
            JSON.stringify(error));
        });
    } catch (error) {
      hilog.warn(DOMAIN, 'Kotoba', 'Unable to prepare the main window: %{public}s', JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (error) => {
      if (error.code !== 0) {
        hilog.error(DOMAIN, 'Kotoba', 'Failed to load page: %{public}s', JSON.stringify(error));
        return;
      }
      this.applyWindowAppearance();
    });
  }

  onForeground(): void {
    this.applyWindowAppearance();
  }

  onDestroy(): void {
    JapaneseTtsService.release();
    MusicPlaybackService.release();
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    this.applyWindowAppearance(newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }

  private applyWindowAppearance(darkFallback?: boolean): void {
    if (this.mainWindow === undefined) {
      return;
    }

    const darkMode: boolean = darkFallback ??
      this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const surfaceColor: string = this.resourceColor('surface', darkMode ? '#17181A' : '#F2F4F7');
    const contentColor: string = this.resourceColor('ink', darkMode ? '#F4F6FA' : '#202124');

    try {
      this.mainWindow.setWindowBackgroundColor(surfaceColor);
      this.mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: contentColor,
        enableStatusBarAnimation: true
      }).catch((error: Object) => {
        hilog.warn(DOMAIN, 'Kotoba', 'Unable to update system bar appearance: %{public}s',
          JSON.stringify(error));
      });
      this.mainWindow.setSpecificSystemBarEnabled('navigationIndicator', true, false)
        .catch((error: Object) => {
          hilog.warn(DOMAIN, 'Kotoba', 'Unable to restore the system navigation indicator: %{public}s',
            JSON.stringify(error));
        });
    } catch (error) {
      hilog.warn(DOMAIN, 'Kotoba', 'Unable to apply window colors: %{public}s', JSON.stringify(error));
    }
  }

  private resourceColor(name: string, fallback: string): string {
    try {
      const color: number = this.context.resourceManager.getColorByNameSync(name);
      return `#${((color >>> 0) & 0x00ffffff).toString(16).padStart(6, '0')}`;
    } catch {
      return fallback;
    }
  }
}
