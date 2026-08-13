/**
 * Vue binding: declaring a feature is one composable, or one component.
 *
 * Nothing here talks to Studio — declarations go into the shared registry, and
 * the host (attached once, in your entry point) reports them. A build running
 * outside Studio therefore pays a `Map` insert per declared feature and nothing
 * else: there is no reason to make declaring conditional.
 */
import {
  defineComponent,
  h,
  onScopeDispose,
  ref,
  toValue,
  watch,
  type MaybeRefOrGetter,
  type PropType,
  type Ref,
  type VNode,
} from 'vue';

import {
  declareStudioFeature,
  type StudioFeatureHandle,
  type StudioFeatureInfo,
} from '../index.ts';

/**
 * Declares a feature for as long as the component is mounted, and returns the
 * template ref to bind to the element it paints into:
 *
 * ```vue
 * <script setup lang="ts">
 * const feature = useStudioFeature({
 *   id: 'schedule/session-list',
 *   title: 'Session list',
 *   purpose: 'Lets a client find a class and book it',
 *   behaviors: ['Shows the coming week', 'A full session is marked as such'],
 * })
 * </script>
 *
 * <template>
 *   <section :ref="feature">…</section>
 * </template>
 * ```
 *
 * The ref is optional — a feature declared without one still reaches Studio; it
 * just cannot be found by tapping the preview. Pass a getter or a ref when the
 * passport itself changes with the state.
 */
export function useStudioFeature(
  feature: MaybeRefOrGetter<StudioFeatureInfo>,
): Ref<Element | null> {
  const element = ref<Element | null>(null);
  let handle: StudioFeatureHandle | null = null;

  watch(
    [() => toValue(feature), element],
    ([passport, node]) => {
      if (handle === null) {
        handle = declareStudioFeature(passport, node);
      } else {
        handle.update(passport);
        handle.attach(node);
      }
    },
    // Deep, because the passport is normally written inline and is a new object
    // every time it is read; what matters is whether its text changed.
    { immediate: true, deep: true },
  );

  onScopeDispose(() => {
    handle?.release();
    handle = null;
  });

  return element;
}

/**
 * The same declaration as a wrapper, for when you have no element of your own
 * to bind the ref to:
 *
 * ```vue
 * <StudioFeature id="schedule/session-list" title="Session list">
 *   <SessionList />
 * </StudioFeature>
 * ```
 *
 * The wrapper renders a `display: contents` box, so it adds a node to the DOM
 * (which is what tap-to-inspect finds) without adding a box to the layout.
 */
export const StudioFeature = defineComponent({
  name: 'StudioFeature',
  props: {
    id: { type: String, required: true },
    title: { type: String, required: true },
    purpose: { type: String, default: undefined },
    behaviors: { type: Array as PropType<string[]>, default: undefined },
    requirements: { type: Array as PropType<string[]>, default: undefined },
    implementationNotes: { type: Array as PropType<string[]>, default: undefined },
    knownIssues: { type: Array as PropType<string[]>, default: undefined },
  },
  setup(props, { slots }) {
    const element = useStudioFeature(() => ({
      id: props.id,
      title: props.title,
      purpose: props.purpose,
      behaviors: props.behaviors,
      requirements: props.requirements,
      implementationNotes: props.implementationNotes,
      knownIssues: props.knownIssues,
    }));

    return (): VNode =>
      h('div', { ref: element, style: { display: 'contents' } }, slots.default?.());
  },
});
