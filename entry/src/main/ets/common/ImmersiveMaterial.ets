import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

let cachedHighest: SystemMaterialParams | undefined = undefined;

function resolveHighestImmersiveMaterial(): SystemMaterialParams {
  let immersive = false;
  try {
    const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    immersive = types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
  } catch (_error) {
    immersive = false;
  }
  return {
    materialType: immersive ? hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: immersive ? hdsMaterial.MaterialLevel.EXQUISITE : hdsMaterial.MaterialLevel.ADAPTIVE
  };
}

/**
 * Highest HDS immersive grade the device can run. Cached because title bars
 * and tabs call this during build; a new object every frame can reset the bar.
 */
export function preferredImmersiveMaterial(): SystemMaterialParams {
  if (cachedHighest === undefined) {
    cachedHighest = resolveHighestImmersiveMaterial();
  }
  return cachedHighest;
}

/**
 * Same grade as the title bars. The bottom bars used to ask for IMMERSIVE at
 * ADAPTIVE level; EXQUISITE is the actual top rung once the device allows it.
 */
export function bottomBarImmersiveMaterial(): SystemMaterialParams {
  return preferredImmersiveMaterial();
}

/**
 * ArkUI floating chrome: buttons, chips, and toolbars that sit on content.
 * Auto-invert only works on THIN / ULTRA_THIN and only for sys.color.*.
 */
export const FLOATING_CHROME_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
  style: uiMaterial.ImmersiveStyle.THIN,
  colorInvert: true,
  interactive: true,
  lightEffect: {
    color: Color.White
  }
});
