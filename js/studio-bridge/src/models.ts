/**
 * The models an app declares about itself, and their wire encoding.
 *
 * Every `...ToJson` here mirrors the Dart package field for field, *including
 * which fields are omitted when empty*: Studio parses leniently, but a format
 * that drifts silently is exactly what the golden-string tests exist to catch.
 */

/** Who can enter a navigation zone. */
export type StudioZoneAccess =
  /** Reachable only when a user is signed in. */
  | 'signedIn'
  /**
   * Reachable only when signed out; activating it while signed in means
   * "sign out" (e.g. an auth zone).
   */
  | 'signedOut'
  /** Reachable regardless of the session. */
  | 'any';

/**
 * The screen passport declared in the app's code: functional specification
 * plus product context, keyed by the screen's route path.
 *
 * Screens are identified by plain path strings so the bridge stays independent
 * of any router — convert your typed routes to paths when declaring specs.
 *
 * Passport texts are plain single-language strings: whatever language the
 * project team writes its specs in is what Studio shows.
 */
export interface StudioScreenSpec {
  /** Full route path of the screen, e.g. `/schedule/profile`. */
  path: string;
  /** Full path of the parent screen (breadcrumb chain), omitted for roots. */
  parentPath?: string | undefined;
  title: string;
  /** CJM / business context: why this screen exists. */
  purpose: string;
  discussionQuestions?: string[] | undefined;
}

/**
 * A navigation zone of the app: a labelled group of screens with a root route.
 * Zones have no display metadata in routers — it lives here.
 */
export interface StudioZoneSpec {
  label: string;
  /** Full path of the zone's root screen. */
  rootPath: string;
  /** Defaults to `any`. */
  access?: StudioZoneAccess | undefined;
  screens: StudioScreenSpec[];
}

/**
 * A product feature — both as the app declares it next to the code and as it
 * travels over the wire.
 *
 * The fields split by audience, and Studio shows them accordingly: `title`,
 * `purpose` and `behaviors` are what a client reads, while `requirements`,
 * `implementationNotes` and `knownIssues` are written for the team.
 */
export interface StudioFeatureInfo {
  /**
   * Stable id — deduplicates a feature declared by several components, and the
   * name feedback and tracker items refer it by. A contract: never renamed in
   * place.
   */
  id: string;
  title: string;
  /**
   * Why the feature exists for the user; omitted for parts that serve a screen
   * rather than carrying a purpose of their own.
   */
  purpose?: string | undefined;
  /** What the feature observably does — one checkable statement per entry. */
  behaviors?: string[] | undefined;
  /** What it must honour, imposed from outside the feature. */
  requirements?: string[] | undefined;
  /** Decisions the team should not have to re-open. Technical side only. */
  implementationNotes?: string[] | undefined;
  /**
   * What is wrong in the feature and worth taking into work. Studio filters on
   * this to show which features carry open questions.
   */
  knownIssues?: string[] | undefined;
}

/**
 * Everything an app declares about itself for Studio: navigation zones with
 * screen passports, the feature catalog and the UI locales it can switch
 * between.
 *
 * Demo personas are deliberately NOT part of the manifest: test users and
 * their codes are configured in Studio, so a public web build never ships a
 * list of privileged test accounts.
 */
export interface StudioProjectManifest {
  projectName: string;
  zones: StudioZoneSpec[];
  /**
   * The app's complete feature catalog. Studio diffs it against its own
   * records on every connect — new features surface immediately, and a feature
   * that vanished while carrying open work is flagged instead of silently
   * unlinking. The live per-screen subset is reported separately, as the app
   * navigates.
   */
  features?: StudioFeatureInfo[] | undefined;
  /**
   * Language tags of the app's UI locales (e.g. `['en', 'ru']`), first one is
   * the default. Zero or one locale means the app is not switchable and Studio
   * hides its locale control.
   */
  supportedLocales?: string[] | undefined;
}

/**
 * The app's current session as far as Studio needs to know: whether someone is
 * signed in, who it is (by the app's own identifier), and whether a requested
 * sign-in is still in flight.
 */
export interface StudioSessionState {
  isSignedIn: boolean;
  /**
   * The signed-in user's identifier in the form the app's auth uses (phone,
   * email). Studio matches it against its own configured demo personas — the
   * app knows nothing about personas.
   */
  userIdentifier?: string | undefined;
  /** Label to show for the current user (e.g. profile name). */
  displayLabel?: string | undefined;
  /** True while the app is executing a requested sign-in or sign-out. */
  isBusy?: boolean | undefined;
}

export const signedOutSession: StudioSessionState = { isSignedIn: false };

// --- encoding ---------------------------------------------------------------

type Json = Record<string, unknown>;

export function featureToJson(feature: StudioFeatureInfo): Json {
  const json: Json = { id: feature.id, title: feature.title };
  if (feature.purpose != null) json.purpose = feature.purpose;
  if (feature.behaviors?.length) json.behaviors = feature.behaviors;
  if (feature.requirements?.length) json.requirements = feature.requirements;
  if (feature.implementationNotes?.length) {
    json.implementationNotes = feature.implementationNotes;
  }
  if (feature.knownIssues?.length) json.knownIssues = feature.knownIssues;
  return json;
}

export function screenToJson(screen: StudioScreenSpec): Json {
  const json: Json = { path: screen.path };
  if (screen.parentPath != null) json.parentPath = screen.parentPath;
  json.title = screen.title;
  json.purpose = screen.purpose;
  json.discussionQuestions = screen.discussionQuestions ?? [];
  return json;
}

export function zoneToJson(zone: StudioZoneSpec): Json {
  return {
    label: zone.label,
    rootPath: zone.rootPath,
    access: zone.access ?? 'any',
    screens: zone.screens.map(screenToJson),
  };
}

export function manifestToJson(manifest: StudioProjectManifest): Json {
  return {
    projectName: manifest.projectName,
    zones: manifest.zones.map(zoneToJson),
    features: (manifest.features ?? []).map(featureToJson),
    supportedLocales: manifest.supportedLocales ?? [],
  };
}

export function sessionToJson(session: StudioSessionState): Json {
  const json: Json = { isSignedIn: session.isSignedIn };
  if (session.userIdentifier != null) json.userIdentifier = session.userIdentifier;
  if (session.displayLabel != null) json.displayLabel = session.displayLabel;
  json.isBusy = session.isBusy ?? false;
  return json;
}

// --- decoding ---------------------------------------------------------------
//
// Lenient throughout, exactly as on the Dart side: an app built against an
// older bridge sends neither the new lists nor `purpose`, and one built against
// a newer bridge may send fields this version has never heard of. Both keep
// working.

export function asJson(value: unknown): Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Json)
    : {};
}

function asString(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function asOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

export function stringListFromJson(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === 'string') : [];
}

export function featureFromJson(json: Json): StudioFeatureInfo {
  const feature: StudioFeatureInfo = {
    id: asString(json.id),
    title: asString(json.title),
  };
  const purpose = asOptionalString(json.purpose);
  if (purpose !== undefined) feature.purpose = purpose;
  const behaviors = stringListFromJson(json.behaviors);
  if (behaviors.length) feature.behaviors = behaviors;
  const requirements = stringListFromJson(json.requirements);
  if (requirements.length) feature.requirements = requirements;
  const implementationNotes = stringListFromJson(json.implementationNotes);
  if (implementationNotes.length) feature.implementationNotes = implementationNotes;
  const knownIssues = stringListFromJson(json.knownIssues);
  if (knownIssues.length) feature.knownIssues = knownIssues;
  return feature;
}

export function featureListFromJson(value: unknown): StudioFeatureInfo[] {
  return Array.isArray(value)
    ? value
        .filter((item) => typeof item === 'object' && item !== null && !Array.isArray(item))
        .map((item) => featureFromJson(item as Json))
    : [];
}

export function screenFromJson(json: Json): StudioScreenSpec {
  const screen: StudioScreenSpec = {
    path: asString(json.path),
    title: asString(json.title),
    purpose: asString(json.purpose),
    discussionQuestions: stringListFromJson(json.discussionQuestions),
  };
  const parentPath = asOptionalString(json.parentPath);
  if (parentPath !== undefined) screen.parentPath = parentPath;
  return screen;
}

export function zoneFromJson(json: Json): StudioZoneSpec {
  const access = asString(json.access);
  return {
    label: asString(json.label),
    rootPath: asString(json.rootPath, '/'),
    access:
      access === 'signedIn' || access === 'signedOut' || access === 'any' ? access : 'any',
    screens: Array.isArray(json.screens)
      ? json.screens
          .filter((item) => typeof item === 'object' && item !== null && !Array.isArray(item))
          .map((item) => screenFromJson(item as Json))
      : [],
  };
}

export function manifestFromJson(json: Json): StudioProjectManifest {
  return {
    projectName: asString(json.projectName),
    zones: Array.isArray(json.zones)
      ? json.zones
          .filter((item) => typeof item === 'object' && item !== null && !Array.isArray(item))
          .map((item) => zoneFromJson(item as Json))
      : [],
    features: featureListFromJson(json.features),
    supportedLocales: stringListFromJson(json.supportedLocales),
  };
}

export function sessionFromJson(json: Json): StudioSessionState {
  const session: StudioSessionState = {
    isSignedIn: json.isSignedIn === true,
    isBusy: json.isBusy === true,
  };
  const userIdentifier = asOptionalString(json.userIdentifier);
  if (userIdentifier !== undefined) session.userIdentifier = userIdentifier;
  const displayLabel = asOptionalString(json.displayLabel);
  if (displayLabel !== undefined) session.displayLabel = displayLabel;
  return session;
}
