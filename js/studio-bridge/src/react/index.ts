/**
 * React binding: declaring a feature is one hook, or one component.
 *
 * Nothing here talks to Studio — declarations go into the shared registry, and
 * the host (attached once, in your entry point) reports them. A build running
 * outside Studio therefore pays a `Map` insert per declared feature and nothing
 * else: there is no reason to make declaring conditional.
 */
import { createElement, useCallback, useEffect, useRef, type ReactNode } from 'react';

import {
  declareStudioFeature,
  type StudioFeatureElement,
  type StudioFeatureHandle,
  type StudioFeatureInfo,
} from '../index.ts';

/**
 * Declares a feature for as long as the component is mounted, and returns a ref
 * to put on the element it paints into:
 *
 * ```tsx
 * const feature = useStudioFeature({
 *   id: 'schedule/session-list',
 *   title: 'Session list',
 *   purpose: 'Lets a client find a class and book it',
 *   behaviors: ['Shows the coming week', 'A full session is marked as such'],
 * });
 * return <section ref={feature}>…</section>;
 * ```
 *
 * The ref is optional — a feature declared without one still reaches Studio; it
 * just cannot be found by tapping the preview.
 */
export function useStudioFeature(feature: StudioFeatureInfo): (element: Element | null) => void {
  const handle = useRef<StudioFeatureHandle | null>(null);
  const element = useRef<StudioFeatureElement | null>(null);

  // The passport itself is the identity: written inline, it is a new object on
  // every render, and a new object every render would re-declare on every
  // render. Its text is what actually changed or did not.
  const passport = JSON.stringify(feature);

  useEffect(() => {
    const declared = declareStudioFeature(
      JSON.parse(passport) as StudioFeatureInfo,
      element.current,
    );
    handle.current = declared;
    return () => {
      declared.release();
      handle.current = null;
    };
  }, [passport]);

  return useCallback((node: Element | null) => {
    element.current = node;
    handle.current?.attach(node);
  }, []);
}

export interface StudioFeatureProps extends StudioFeatureInfo {
  children?: ReactNode;
}

/**
 * The same declaration as a wrapper, for when you have no element of your own
 * to hang the ref on:
 *
 * ```tsx
 * <StudioFeature id="schedule/session-list" title="Session list">
 *   <SessionList />
 * </StudioFeature>
 * ```
 *
 * The wrapper renders a `display: contents` box, so it adds a node to the DOM
 * (which is what tap-to-inspect finds) without adding a box to the layout.
 */
export function StudioFeature({ children, ...feature }: StudioFeatureProps): ReactNode {
  const ref = useStudioFeature(feature);
  return createElement('div', { ref, style: featureBoxStyle }, children);
}

const featureBoxStyle = { display: 'contents' } as const;
