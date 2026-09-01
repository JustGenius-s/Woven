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

/**
 * Material for the floating bottom bars (tab bar and mini player).
 *
 * ADAPTIVE is documented as defaulting to the immersive material, but the
 * official HdsTabs immersive sample asks for IMMERSIVE explicitly, and the
 * bottom bars showed a noticeably weaker effect under ADAPTIVE. The level
 * stays ADAPTIVE so the system still tunes the strength per device.
 */
export function bottomBarImmersiveMaterial(): SystemMaterialParams {
  return {
    materialType: hdsMaterial.MaterialType.IMMERSIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}
