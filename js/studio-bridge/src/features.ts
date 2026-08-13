import type { StudioFeatureInfo } from './models.ts';

/**
 * The bit of a DOM element the registry needs. Any real `Element` satisfies it;
 * so does a plain object, which is what lets the hit test be tested without a
 * browser.
 */
export interface StudioFeatureElement {
  getBoundingClientRect(): { left: number; top: number; right: number; bottom: number };
  readonly parentElement: StudioFeatureElement | null;
}

/** A live declaration. Keep it for as long as the feature is on screen. */
export interface StudioFeatureHandle {
  /** Replaces the passport — the new text is reported on the next flush. */
  update(feature: StudioFeatureInfo): void;
  /** Binds (or unbinds) the element the feature paints into, for tap-to-inspect. */
  attach(element: StudioFeatureElement | null): void;
  /** Withdraws the declaration. Safe to call twice. */
  release(): void;
}

/**
 * Where the app currently paints. Defaults to the browser window; passed
 * explicitly by tests and by anything rendering outside a plain document.
 */
export interface StudioFeatureViewport {
  width: number;
  height: number;
  elementFromPoint?: ((x: number, y: number) => StudioFeatureElement | null) | undefined;
}

interface Entry {
  feature: StudioFeatureInfo;
  element: StudioFeatureElement | null;
}

/**
 * What the app has declared about the screen it is showing right now.
 *
 * The registry is deliberately independent of the bridge host: components
 * declare their features whether or not the app is being previewed, and whether
 * or not the host has attached yet. Declaring therefore costs one call that
 * cannot fail and cannot depend on load order — which is the whole point, since
 * a feature nobody declared is a feature Studio cannot show.
 */
export class StudioFeatureRegistry {
  #entries = new Map<number, Entry>();
  #listeners = new Set<() => void>();
  #nextKey = 0;

  /** Declares a feature as present on the current screen. */
  declare(feature: StudioFeatureInfo, element: StudioFeatureElement | null = null): StudioFeatureHandle {
    const key = this.#nextKey++;
    this.#entries.set(key, { feature, element });
    this.#notify();

    return {
      update: (next) => {
        const entry = this.#entries.get(key);
        if (entry === undefined) return;
        entry.feature = next;
        this.#notify();
      },
      attach: (next) => {
        const entry = this.#entries.get(key);
        // No notification: where a feature sits changes nothing that travels
        // over the wire, and a report per mounted element would be a flood.
        if (entry !== undefined) entry.element = next;
      },
      release: () => {
        if (this.#entries.delete(key)) this.#notify();
      },
    };
  }

  /**
   * The features on screen, in declaration order, one entry per id: the same
   * feature declared by several components is one feature.
   */
  list(): StudioFeatureInfo[] {
    const byId = new Map<string, StudioFeatureInfo>();
    for (const entry of this.#entries.values()) {
      if (!byId.has(entry.feature.id)) byId.set(entry.feature.id, entry.feature);
    }
    return [...byId.values()];
  }

  /**
   * The feature declared at a point given as fractions of the viewport (0.0
   * top/left, 1.0 bottom/right) — the "pencil" tap-to-inspect flow.
   *
   * The innermost declaration wins: `elementFromPoint` finds what is actually
   * painted there (so something scrolled out of view or covered does not answer
   * for a point where the user sees nothing), then the ancestor chain is walked
   * outwards to the nearest declared element. Where there is no document to ask
   * — tests, exotic renderers — the smallest declared box containing the point
   * is used instead.
   */
  featureAt(
    horizontalFraction: number,
    verticalFraction: number,
    viewport?: StudioFeatureViewport,
  ): StudioFeatureInfo | null {
    const resolved = viewport ?? defaultViewport();
    if (resolved === null) return null;

    const x = horizontalFraction * resolved.width;
    const y = verticalFraction * resolved.height;

    const declared = new Map<StudioFeatureElement, StudioFeatureInfo>();
    for (const entry of this.#entries.values()) {
      if (entry.element !== null && !declared.has(entry.element)) {
        declared.set(entry.element, entry.feature);
      }
    }
    if (declared.size === 0) return null;

    const painted = resolved.elementFromPoint?.(x, y) ?? null;
    if (painted !== null) {
      for (let node: StudioFeatureElement | null = painted; node !== null; node = node.parentElement) {
        const feature = declared.get(node);
        if (feature !== undefined) return feature;
      }
      return null;
    }

    let best: StudioFeatureInfo | null = null;
    let bestArea = Number.POSITIVE_INFINITY;
    for (const [element, feature] of declared) {
      const rect = element.getBoundingClientRect();
      if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) continue;
      const area = (rect.right - rect.left) * (rect.bottom - rect.top);
      if (area < bestArea) {
        best = feature;
        bestArea = area;
      }
    }
    return best;
  }

  /** Notified whenever the declared set or any passport text changes. */
  subscribe(listener: () => void): () => void {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  }

  #notify(): void {
    for (const listener of this.#listeners) listener();
  }
}

function defaultViewport(): StudioFeatureViewport | null {
  if (typeof window === 'undefined') return null;
  return {
    width: window.innerWidth,
    height: window.innerHeight,
    elementFromPoint:
      typeof document === 'undefined' ? undefined : (x, y) => document.elementFromPoint(x, y),
  };
}

/**
 * The registry the framework wrappers and the bridge host share. One per page:
 * a feature belongs to the screen the user is looking at, not to whichever
 * module happened to import the bridge.
 */
export const studioFeatures = new StudioFeatureRegistry();

/**
 * Declares a feature as present on the current screen, and returns the handle
 * that withdraws it.
 *
 * Framework wrappers (`@dartway/studio-bridge/react`, `/vue`) call this for
 * you; reach for it directly in plain JS, or in a framework this package does
 * not wrap yet.
 */
export function declareStudioFeature(
  feature: StudioFeatureInfo,
  element: StudioFeatureElement | null = null,
): StudioFeatureHandle {
  return studioFeatures.declare(feature, element);
}
