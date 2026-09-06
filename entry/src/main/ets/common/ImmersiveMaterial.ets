import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
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

/**
 * Keep the thinnest native filter, with a small theme-aware tint inside the
 * material. A transparent background on the host is not a material fallback.
 */
export const FLOATING_ULTRA_THIN_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
  style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
  materialColor: $r('app.color.immersive_control_tint'),
  colorInvert: true,
  interactive: true,
  lightEffect: {
    color: Color.White
  }
});

const SHEET_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
  // Use the native dialog grade: diffuse the page behind long text/form panels.
  style: uiMaterial.ImmersiveStyle.ULTRA_THICK
});

export interface ImmersiveSurfaceStyle {
  material?: uiMaterial.Material;
  backgroundColor?: ResourceColor;
  blurStyle?: BlurStyle;
}

const NATIVE_FLOATING_POPUP: ImmersiveSurfaceStyle = {
  material: new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    colorInvert: true,
    interactive: true,
    lightEffect: { color: Color.White }
  })
};

let cachedFloatingSurface: ImmersiveSurfaceStyle | undefined = undefined;
let cachedSheetSurface: ImmersiveSurfaceStyle | undefined = undefined;

function resolveArkUISurfaces(): void {
  let supported: boolean = false;
  let smooth: boolean = false;
  try {
    supported = uiMaterial.isImmersiveMaterialSupported() &&
      uiMaterial.getMaterialInfo().state !== uiMaterial.MaterialState.DISABLE;
    smooth = supported && uiMaterial.getGlobalMaterialLevel() === uiMaterial.MaterialLevel.SMOOTH;
  } catch (_error) {
    supported = false;
  }
  if (supported) {
    // SMOOTH uses materialColor as its background, without the refractive filter.
    // Give that native grade enough fill to keep controls and transcript legible.
    cachedFloatingSurface = {
      material: smooth ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        materialColor: $r('app.color.immersive_plane'),
        colorInvert: true,
        interactive: true,
        lightEffect: { color: Color.White }
      }) : FLOATING_ULTRA_THIN_MATERIAL
    };
    cachedSheetSurface = {
      material: smooth ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
        materialColor: $r('app.color.immersive_plane_strong')
      }) : SHEET_MATERIAL
    };
  } else {
    // Unsupported/disabled ArkUI material must not leave a transparent host.
    cachedFloatingSurface = {
      backgroundColor: $r('app.color.immersive_plane'),
      blurStyle: BlurStyle.COMPONENT_ULTRA_THIN
    };
    cachedSheetSurface = {
      backgroundColor: $r('app.color.immersive_plane_strong'),
      blurStyle: BlurStyle.COMPONENT_ULTRA_THICK
    };
  }
}

function floatingSurface(): ImmersiveSurfaceStyle {
  if (cachedFloatingSurface === undefined) { resolveArkUISurfaces(); }
  return cachedFloatingSurface!;
}

/** One material on the outer surface; inner transport buttons share its rim. */
export class FloatingImmersiveSurface implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    const surface: ImmersiveSurfaceStyle = floatingSurface();
    // Undefined clears conflicting overrides on the native material path.
    instance.backgroundColor(surface.backgroundColor);
    instance.backgroundBlurStyle(surface.blurStyle);
    instance.systemMaterial(surface.material);
  }
}

export const FLOATING_IMMERSIVE_SURFACE: FloatingImmersiveSurface = new FloatingImmersiveSurface();

function immersiveSheetSurface(): ImmersiveSurfaceStyle {
  if (cachedSheetSurface === undefined) { resolveArkUISurfaces(); }
  return cachedSheetSurface!;
}

/** All sheets share material, scrim and corners; callers own content and lifecycle. */
export function appSheetOptions(options: SheetOptions): SheetOptions {
  const surface: ImmersiveSurfaceStyle = immersiveSheetSurface();
  options.systemMaterial = surface.material;
  options.backgroundColor = surface.backgroundColor;
  options.blurStyle = surface.blurStyle;
  options.maskColor = $r('app.color.sheet_mask');
  options.radius = LengthMetrics.vp(28);
  options.preferType = SheetType.BOTTOM;
  options.dragBar = true;
  return options;
}

/**
 * Ordinary page Stacks are outside ArkUI's immersive material scope. Put the
 * call capsule on CustomPopupOptions.systemMaterial, not on its builder root.
 */
export function immersiveFloatingPopupSurface(): ImmersiveSurfaceStyle {
  const surface: ImmersiveSurfaceStyle = floatingSurface();
  return surface.material === FLOATING_ULTRA_THIN_MATERIAL ? NATIVE_FLOATING_POPUP : surface;
}
