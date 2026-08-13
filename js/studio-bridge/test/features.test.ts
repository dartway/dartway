import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { StudioFeatureRegistry, type StudioFeatureElement } from '../src/index.ts';

interface Rect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

class FakeElement implements StudioFeatureElement {
  readonly parentElement: StudioFeatureElement | null;
  #rect: Rect;

  constructor(rect: Rect, parentElement: StudioFeatureElement | null = null) {
    this.#rect = rect;
    this.parentElement = parentElement;
  }

  getBoundingClientRect(): Rect {
    return this.#rect;
  }
}

/** A 400×800 phone-shaped viewport, so fractions turn into round numbers. */
const viewport = (elementFromPoint?: (x: number, y: number) => StudioFeatureElement | null) => ({
  width: 400,
  height: 800,
  ...(elementFromPoint === undefined ? {} : { elementFromPoint }),
});

describe('what is on screen', () => {
  test('features are listed in declaration order', () => {
    const registry = new StudioFeatureRegistry();
    registry.declare({ id: 'a', title: 'A' });
    registry.declare({ id: 'b', title: 'B' });

    assert.deepEqual(
      registry.list().map((feature) => feature.id),
      ['a', 'b'],
    );
  });

  test('one feature declared by several components is one feature', () => {
    const registry = new StudioFeatureRegistry();
    registry.declare({ id: 'card', title: 'Card' });
    registry.declare({ id: 'card', title: 'Card' });
    registry.declare({ id: 'card', title: 'Card' });

    assert.equal(registry.list().length, 1);
  });

  test('a released feature leaves the screen', () => {
    const registry = new StudioFeatureRegistry();
    const handle = registry.declare({ id: 'a', title: 'A' });
    handle.release();
    handle.release(); // idempotent

    assert.deepEqual(registry.list(), []);
  });

  test('an updated passport replaces the old text', () => {
    const registry = new StudioFeatureRegistry();
    const handle = registry.declare({ id: 'a', title: 'A' });
    handle.update({ id: 'a', title: 'A', knownIssues: ['the empty state is missing'] });

    assert.deepEqual(registry.list()[0]?.knownIssues, ['the empty state is missing']);
  });

  test('subscribers hear a change of declarations, but not a change of position', () => {
    const registry = new StudioFeatureRegistry();
    let changes = 0;
    const unsubscribe = registry.subscribe(() => {
      changes++;
    });

    const handle = registry.declare({ id: 'a', title: 'A' });
    handle.update({ id: 'a', title: 'A2' });
    handle.attach(new FakeElement({ left: 0, top: 0, right: 10, bottom: 10 }));
    handle.release();
    assert.equal(changes, 3);

    unsubscribe();
    registry.declare({ id: 'b', title: 'B' });
    assert.equal(changes, 3);
  });
});

describe('the point Studio taps', () => {
  test('the innermost declaration around what is painted there wins', () => {
    const registry = new StudioFeatureRegistry();
    const screen = new FakeElement({ left: 0, top: 0, right: 400, bottom: 800 });
    const card = new FakeElement({ left: 0, top: 100, right: 400, bottom: 300 }, screen);
    const painted = new FakeElement({ left: 10, top: 110, right: 100, bottom: 140 }, card);

    registry.declare({ id: 'schedule', title: 'Schedule' }, screen);
    registry.declare({ id: 'schedule/card', title: 'Session card' }, card);

    assert.equal(
      registry.featureAt(0.5, 0.25, viewport(() => painted))?.id,
      'schedule/card',
    );
  });

  test('nothing is answered for a point outside every declaration', () => {
    const registry = new StudioFeatureRegistry();
    const card = new FakeElement({ left: 0, top: 100, right: 400, bottom: 300 });
    const elsewhere = new FakeElement({ left: 0, top: 700, right: 400, bottom: 800 });
    registry.declare({ id: 'schedule/card', title: 'Session card' }, card);

    assert.equal(registry.featureAt(0.5, 0.95, viewport(() => elsewhere)), null);
  });

  test('a feature declared without an element cannot be tapped', () => {
    const registry = new StudioFeatureRegistry();
    registry.declare({ id: 'a', title: 'A' });

    assert.equal(registry.featureAt(0.5, 0.5, viewport(() => null)), null);
  });

  test('with no document to ask, the smallest box containing the point answers', () => {
    const registry = new StudioFeatureRegistry();
    registry.declare(
      { id: 'schedule', title: 'Schedule' },
      new FakeElement({ left: 0, top: 0, right: 400, bottom: 800 }),
    );
    registry.declare(
      { id: 'schedule/card', title: 'Session card' },
      new FakeElement({ left: 0, top: 100, right: 400, bottom: 300 }),
    );

    assert.equal(registry.featureAt(0.5, 0.25, viewport())?.id, 'schedule/card');
    assert.equal(registry.featureAt(0.5, 0.75, viewport())?.id, 'schedule');
  });
});
