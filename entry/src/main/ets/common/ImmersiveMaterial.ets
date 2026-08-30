import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

/**
 * Let HarmonyOS choose both the material implementation and its level.
 * This keeps immersive light aligned with the user's system policy and the
 * current device capability instead of forcing an app-defined strength.
 */
export function preferredImmersiveMaterial(): SystemMaterialParams {
  return {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}
