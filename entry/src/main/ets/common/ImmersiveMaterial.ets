import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

/**
 * Prefer HarmonyOS 6.1's native immersive-light material when the current
 * device exposes it. ADAPTIVE keeps the UI functional on devices where the
 * immersive implementation is reduced by capability or thermal policy.
 */
export function preferredImmersiveMaterial(): SystemMaterialParams {
  let materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.ADAPTIVE;

  try {
    const supportedTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    for (let index: number = 0; index < supportedTypes.length; index++) {
      if (supportedTypes[index] === hdsMaterial.MaterialType.IMMERSIVE) {
        materialType = hdsMaterial.MaterialType.IMMERSIVE;
        break;
      }
    }
  } catch {
    materialType = hdsMaterial.MaterialType.ADAPTIVE;
  }

  return {
    materialType: materialType,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}
