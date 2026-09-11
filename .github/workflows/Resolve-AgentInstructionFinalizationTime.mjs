// Resolve an authenticated finalization timestamp for agent-document metadata.

import { appendFileSync } from 'node:fs';
import { setTimeout as delay } from 'node:timers/promises';
import { pathToFileURL } from 'node:url';

const objectIdPattern = /^[0-9a-f]{40}$/u;
const positiveIntegerPattern = /^[1-9][0-9]*$/u;
const repositoryPattern = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/u;
const repositoryRefPattern = /^refs\/(?:heads|tags)\/(.+)$/u;
const rfc3339UtcPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u;
const maximumPageCount = 20;
const recordsPerPage = 100;
const maximumClockSkewMilliseconds = 300_000;
const publicationRetryDelaysMilliseconds = Object.freeze([250, 1_000, 2_000]);

class NoExactHeadPublicationError extends Error {}

function parseTimestamp(value, maximumTime, displayName) {
  const time = Date.parse(value ?? '');
  if (!rfc3339UtcPattern.test(value ?? '') || !Number.isFinite(time) ||
      time > maximumTime) {
    throw new Error(`${displayName} is unavailable or invalid.`);
  }
  return time;
}

async function readJson(url, token, fetchImplementation, displayName) {
  const headers = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const response = await fetchImplementation(url, {
    headers,
  });
  if (!response?.ok) {
    throw new Error(`${displayName} failed: ${response?.status ?? 'unknown'}.`);
  }
  return {
    headers: response.headers,
    value: await response.json(),
  };
}

function readNextActivityUrl(link, initialUrl) {
  if (!link) {
    return null;
  }
  const nextMatches = [...link.matchAll(/<([^<>]+)>\s*;\s*rel="next"/gu)];
  if (nextMatches.length === 0) {
    if (/rel\s*=\s*"next"/u.test(link)) {
      throw new Error('The repository-activity pagination link is malformed.');
    }
    return null;
  }
  if (nextMatches.length !== 1) {
    throw new Error('The repository-activity response has multiple next links.');
  }

  let candidate;
  try {
    candidate = new URL(nextMatches[0][1]);
  } catch {
    throw new Error('The repository-activity pagination link is invalid.');
  }
  if (candidate.origin !== initialUrl.origin ||
      candidate.pathname !== initialUrl.pathname ||
      candidate.username || candidate.password || candidate.hash) {
    throw new Error('The repository-activity pagination link crosses its trust boundary.');
  }

  const expectedParameters = new Map([
    ['direction', 'desc'],
    ['per_page', String(recordsPerPage)],
    ['ref', initialUrl.searchParams.get('ref')],
  ]);
  const allowedParameters = new Set([...expectedParameters.keys(), 'after', 'before']);
  for (const key of candidate.searchParams.keys()) {
    if (!allowedParameters.has(key)) {
      throw new Error('The repository-activity pagination link has an unexpected parameter.');
    }
  }
  for (const [key, value] of expectedParameters) {
    const values = candidate.searchParams.getAll(key);
    if (values.length !== 1 || values[0] !== value) {
      throw new Error('The repository-activity pagination link changed the query identity.');
    }
  }
  const cursorParameters = ['after', 'before'].filter(
    (key) => candidate.searchParams.has(key),
  );
  if (cursorParameters.length !== 1) {
    throw new Error('The repository-activity pagination link has an invalid cursor.');
  }
  const cursorName = cursorParameters[0];
  const cursorValues = candidate.searchParams.getAll(cursorName);
  if (cursorValues.length !== 1 || !cursorValues[0]) {
    throw new Error('The repository-activity pagination link has an invalid cursor.');
  }

  const nextUrl = new URL(initialUrl);
  nextUrl.searchParams.set(cursorName, cursorValues[0]);
  return nextUrl;
}

function validateRepositoryActivity(activity, expected, currentCreatedTime) {
  const knownActivityTypes = [
    'push',
    'force_push',
    'branch_creation',
    'branch_deletion',
    'pr_merge',
    'merge_queue_merge',
  ];
  if (!Number.isSafeInteger(activity?.id) || activity.id <= 0 ||
      !knownActivityTypes.includes(activity?.activity_type) ||
      activity?.ref !== expected.ref) {
    throw new Error('A head repository activity has an unexpected identity.');
  }
  if (!['push', 'force_push', 'branch_creation'].includes(activity.activity_type)) {
    return null;
  }
  if (!objectIdPattern.test(activity?.before ?? '') ||
      !objectIdPattern.test(activity?.after ?? '')) {
    throw new Error('A head publication activity has a malformed revision.');
  }
  if (activity.after !== expected.revision) {
    return null;
  }
  if (expected.baseRevision && activity.before !== expected.baseRevision) {
    throw new Error('The head publication activity has an unexpected prior revision.');
  }
  const createdTime = parseTimestamp(
    activity.timestamp,
    currentCreatedTime,
    'A head repository-activity timestamp',
  );
  return { createdAt: activity.timestamp, createdTime };
}

async function readHeadPublication({
  root,
  headRepository,
  headRef,
  headRevision,
  headBaseRevision = null,
  token,
  fetchImplementation,
  currentCreatedTime,
}) {
  const initialUrl = new URL(`${root}/repos/${headRepository}/activity`);
  initialUrl.searchParams.set('direction', 'desc');
  initialUrl.searchParams.set('per_page', String(recordsPerPage));
  initialUrl.searchParams.set('ref', headRef);
  const seenIds = new Set();
  const candidates = [];
  const expected = {
    ref: headRef,
    revision: headRevision,
    baseRevision: headBaseRevision,
  };
  let url = initialUrl;
  for (let page = 1; page <= maximumPageCount; page += 1) {
    const response = await readJson(
      url,
      token,
      fetchImplementation,
      'Head repository-activity lookup',
    );
    if (!Array.isArray(response.value)) {
      throw new Error('The head repository-activity response is malformed.');
    }
    for (const activity of response.value) {
      if (seenIds.has(activity?.id)) {
        throw new Error('The head repository-activity response contains a duplicate.');
      }
      seenIds.add(activity?.id);
      const candidate = validateRepositoryActivity(
        activity,
        expected,
        currentCreatedTime,
      );
      if (candidate) {
        candidates.push(candidate);
      }
    }
    candidates.sort((left, right) => right.createdTime - left.createdTime);
    if (candidates.length > 0) {
      return candidates[0].createdAt;
    }

    const nextUrl = readNextActivityUrl(
      response.headers?.get?.('link') ?? '',
      initialUrl,
    );
    if (!nextUrl) {
      break;
    }
    if (page === maximumPageCount) {
      throw new Error(
        `Repository-activity pagination exceeded ${maximumPageCount} pages.`,
      );
    }
    url = nextUrl;
  }
  throw new NoExactHeadPublicationError(
    'No exact head publication activity matches this revision and ref.',
  );
}

async function readHeadPublicationWithRetry({
  root,
  headRepository,
  headRef,
  headRevision,
  headBaseRevision = null,
  token,
  fetchImplementation,
  waitImplementation,
  currentCreatedTime,
}) {
  for (let attempt = 0;
    attempt <= publicationRetryDelaysMilliseconds.length;
    attempt += 1) {
    try {
      return await readHeadPublication({
        root,
        headRepository,
        headRef,
        headRevision,
        headBaseRevision,
        token,
        fetchImplementation,
        currentCreatedTime,
      });
    } catch (error) {
      if (!(error instanceof NoExactHeadPublicationError) ||
          attempt === publicationRetryDelaysMilliseconds.length) {
        throw error;
      }
      await waitImplementation(publicationRetryDelaysMilliseconds[attempt]);
    }
  }
  throw new Error('The bounded publication retry loop did not terminate.');
}

function validateCurrentRun(run, expected) {
  if (String(run?.id) !== expected.runId ||
      run?.repository?.full_name !== expected.repository ||
      run?.head_repository?.full_name !== expected.headRepository ||
      run?.head_sha !== expected.runHeadRevision ||
      run?.head_branch !== expected.runHeadRefName ||
      run?.event !== expected.eventName ||
      String(run?.run_attempt) !== expected.runAttempt ||
      !Number.isSafeInteger(run?.workflow_id) || run.workflow_id <= 0 ||
      typeof run?.path !== 'string' || run.path.length === 0) {
    throw new Error('The workflow-run response identity does not match this run.');
  }
}

export async function resolveFinalizationTimestamp({
  apiUrl,
  repository,
  runId,
  runAttempt,
  eventName,
  runBaseRevision,
  runHeadRevision,
  runHeadRefName,
  runHeadRef,
  runHeadRepository,
  token,
  now = Date.now(),
  fetchImplementation = globalThis.fetch,
  waitImplementation = delay,
}) {
  if (!apiUrl || !repositoryPattern.test(repository ?? '') ||
      !positiveIntegerPattern.test(runId ?? '') ||
      !positiveIntegerPattern.test(runAttempt ?? '') ||
      !['push', 'pull_request_target', 'workflow_dispatch'].includes(eventName) ||
      (eventName === 'push' && !objectIdPattern.test(runBaseRevision ?? '')) ||
      !objectIdPattern.test(runHeadRevision ?? '') || !runHeadRefName ||
      !repositoryPattern.test(runHeadRepository ?? '') ||
      /[\u0000\r\n]/u.test(runHeadRefName) ||
      /[\u0000\r\n]/u.test(runHeadRef ?? '') || !token ||
      !Number.isFinite(now) || typeof fetchImplementation !== 'function' ||
      typeof waitImplementation !== 'function') {
    throw new Error('Trusted workflow-run inputs are unavailable or invalid.');
  }
  const refMatch = repositoryRefPattern.exec(runHeadRef ?? '');
  if (!refMatch || refMatch[1] !== runHeadRefName) {
    throw new Error('The workflow-run full ref does not match its short name.');
  }
  if (eventName !== 'pull_request_target' && runHeadRepository !== repository) {
    throw new Error('The workflow-run head repository is invalid for this event.');
  }

  const root = apiUrl.replace(/\/+$/u, '');
  const currentResponse = await readJson(
    `${root}/repos/${repository}/actions/runs/${runId}`,
    token,
    fetchImplementation,
    'Workflow-run lookup',
  );
  const currentRun = currentResponse.value;
  const expectedCurrent = {
    runId,
    runAttempt,
    repository,
    runHeadRevision,
    runHeadRefName,
    headRepository: runHeadRepository,
    eventName,
  };
  validateCurrentRun(currentRun, expectedCurrent);
  const currentCreatedTime = parseTimestamp(
    currentRun.created_at,
    now + maximumClockSkewMilliseconds,
    'The workflow-run creation time',
  );
  return readHeadPublicationWithRetry({
    root,
    headRepository: runHeadRepository,
    headRef: runHeadRef,
    headRevision: runHeadRevision,
    headBaseRevision: eventName === 'push' ? runBaseRevision : null,
    token: runHeadRepository === repository ? token : null,
    fetchImplementation,
    waitImplementation,
    currentCreatedTime,
  });
}

function makeResponse(value, { link = '', ok = true, status = 200 } = {}) {
  return {
    ok,
    status,
    headers: { get: (name) => name.toLowerCase() === 'link' ? link : null },
    json: async () => value,
  };
}

function makeRun(overrides = {}) {
  return {
    id: 1,
    repository: { full_name: 'owner/repository' },
    head_repository: { full_name: 'owner/repository' },
    head_sha: 'a'.repeat(40),
    head_branch: 'topic/branch',
    event: 'workflow_dispatch',
    run_attempt: 1,
    workflow_id: 99,
    path: '.github/workflows/agent-instructions.yml',
    status: 'in_progress',
    conclusion: null,
    created_at: '2026-09-10T12:00:00Z',
    ...overrides,
  };
}

function makeActivity(overrides = {}) {
  return {
    id: 10,
    activity_type: 'push',
    before: 'b'.repeat(40),
    after: 'a'.repeat(40),
    ref: 'refs/heads/topic/branch',
    timestamp: '2026-09-10T10:00:00Z',
    ...overrides,
  };
}

function makeActivityNextLink(
  headRepository,
  cursor,
  origin = 'https://api.github.example',
  activityRef = 'refs/heads/topic/branch',
) {
  const url = new URL(`${origin}/api/v3/repos/${headRepository}/activity`);
  url.searchParams.set('direction', 'desc');
  url.searchParams.set('per_page', String(recordsPerPage));
  url.searchParams.set('ref', activityRef);
  url.searchParams.set('after', cursor);
  return `<${url}>; rel="next"`;
}

function makeFixtureFetch({
  current = makeRun(),
  forkActivities = [],
  repositoryActivities = [],
  forkActivityPages = null,
  repositoryActivityPages = null,
  activityRef = 'refs/heads/topic/branch',
}) {
  return async (request, options) => {
    const url = new URL(String(request));
    if (url.pathname === '/api/v3/repos/fork-owner/repository/activity') {
      if (options?.headers?.Authorization ||
          url.searchParams.get('direction') !== 'desc' ||
          url.searchParams.get('per_page') !== String(recordsPerPage) ||
          url.searchParams.get('ref') !== activityRef ||
          url.searchParams.has('time_period')) {
        throw new Error('The fork-head activity query is not exact or anonymous.');
      }
      if (!forkActivityPages) {
        return makeResponse(forkActivities);
      }
      const cursor = url.searchParams.get('after') ?? url.searchParams.get('before');
      const page = cursor ? Number(cursor.replace(/^cursor-/u, '')) : 0;
      return forkActivityPages[page] ?? makeResponse([]);
    }
    if (url.pathname === '/api/v3/repos/owner/repository/activity') {
      if (options?.headers?.Authorization !== 'Bearer fixture-token' ||
          url.searchParams.get('direction') !== 'desc' ||
          url.searchParams.get('per_page') !== String(recordsPerPage) ||
          url.searchParams.get('ref') !== activityRef ||
          url.searchParams.has('time_period')) {
        throw new Error('The repository activity query is not exact or authenticated.');
      }
      if (!repositoryActivityPages) {
        return makeResponse(repositoryActivities);
      }
      const cursor = url.searchParams.get('after') ?? url.searchParams.get('before');
      const page = cursor ? Number(cursor.replace(/^cursor-/u, '')) : 0;
      return repositoryActivityPages[page] ?? makeResponse([]);
    }
    if (!url.pathname.startsWith('/api/v3/repos/owner/repository/')) {
      throw new Error('The API base path was not preserved.');
    }
    if (options?.headers?.Authorization !== 'Bearer fixture-token') {
      throw new Error('A base-repository API request was not authenticated.');
    }
    if (url.pathname.endsWith('/actions/runs/1')) {
      return makeResponse(current);
    }
    return makeResponse({}, { ok: false, status: 404 });
  };
}

async function expectRejected(name, action, expectedPattern) {
  try {
    await action();
  } catch (error) {
    if (expectedPattern.test(String(error?.message))) {
      return;
    }
    throw new Error(`Self-test '${name}' returned an unexpected failure: ${error}`);
  }
  throw new Error(`Self-test '${name}' was accepted.`);
}

export async function runSelfTest() {
  const base = {
    apiUrl: 'https://api.github.example/api/v3',
    repository: 'owner/repository',
    runId: '1',
    runAttempt: '1',
    eventName: 'workflow_dispatch',
    runBaseRevision: 'b'.repeat(40),
    runHeadRevision: 'a'.repeat(40),
    runHeadRefName: 'topic/branch',
    runHeadRef: 'refs/heads/topic/branch',
    runHeadRepository: 'owner/repository',
    token: 'fixture-token',
    now: Date.parse('2026-09-10T12:01:00Z'),
  };
  let fixtures = 0;
  const assertEqual = (name, actual, expected) => {
    fixtures += 1;
    if (actual !== expected) {
      throw new Error(`Self-test '${name}' returned '${actual}', expected '${expected}'.`);
    }
  };
  const reject = async (name, action, pattern) => {
    fixtures += 1;
    await expectRejected(name, action, pattern);
  };

  const ordinaryTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'push',
    now: Date.parse('2026-09-11T00:01:00Z'),
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'push',
        created_at: '2026-09-11T00:00:05Z',
      }),
      repositoryActivities: [makeActivity({ timestamp: '2026-09-10T23:59:55Z' })],
    }),
  });
  assertEqual(
    'direct push preserves the preceding UTC publication date',
    ordinaryTimestamp,
    '2026-09-10T23:59:55Z',
  );

  let delayedActivityRequests = 0;
  const delayedWaits = [];
  const delayedBaseFetch = makeFixtureFetch({
    current: makeRun({ event: 'push' }),
  });
  const delayedPushTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'push',
    fetchImplementation: async (request, options) => {
      const url = new URL(String(request));
      if (url.pathname === '/api/v3/repos/owner/repository/activity') {
        delayedActivityRequests += 1;
        return makeResponse(
          delayedActivityRequests === 1 ? [] : [makeActivity()],
        );
      }
      return delayedBaseFetch(request, options);
    },
    waitImplementation: async (milliseconds) => {
      delayedWaits.push(milliseconds);
    },
  });
  assertEqual(
    'direct push retries a briefly absent exact publication',
    `${delayedPushTimestamp}|${delayedActivityRequests}|${delayedWaits.join(',')}`,
    '2026-09-10T10:00:00Z|2|250',
  );

  let mismatchedPriorWaits = 0;
  await reject(
    'direct push rejects a mismatched prior revision',
    () => resolveFinalizationTimestamp({
      ...base,
      eventName: 'push',
      fetchImplementation: makeFixtureFetch({
        current: makeRun({ event: 'push' }),
        repositoryActivities: [makeActivity({ before: 'c'.repeat(40) })],
      }),
      waitImplementation: async () => {
        mismatchedPriorWaits += 1;
      },
    }),
    /unexpected prior revision/u,
  );
  if (mismatchedPriorWaits !== 0) {
    throw new Error('The direct-push identity failure entered the retry path.');
  }

  let absentActivityRequests = 0;
  const absentWaits = [];
  const absentBaseFetch = makeFixtureFetch({
    current: makeRun({ event: 'push' }),
  });
  await reject(
    'direct push fails after bounded publication retries',
    () => resolveFinalizationTimestamp({
      ...base,
      eventName: 'push',
      fetchImplementation: async (request, options) => {
        const url = new URL(String(request));
        if (url.pathname === '/api/v3/repos/owner/repository/activity') {
          absentActivityRequests += 1;
          return makeResponse([]);
        }
        return absentBaseFetch(request, options);
      },
      waitImplementation: async (milliseconds) => {
        absentWaits.push(milliseconds);
      },
    }),
    /No exact head publication activity/u,
  );
  if (absentActivityRequests !== 4 ||
      absentWaits.join(',') !== '250,1000,2000') {
    throw new Error('The direct-push publication retry bound changed.');
  }

  const pullRequestPublicationTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    now: Date.parse('2026-09-11T00:01:00Z'),
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        created_at: '2026-09-11T00:00:05Z',
      }),
      repositoryActivities: [makeActivity({ timestamp: '2026-09-10T23:59:55Z' })],
    }),
  });
  assertEqual(
    'pull request preserves the preceding UTC publication date',
    pullRequestPublicationTimestamp,
    '2026-09-10T23:59:55Z',
  );

  const pullRequestFailedPushPublicationTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    now: Date.parse('2026-09-11T00:01:00Z'),
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        created_at: '2026-09-11T00:00:05Z',
      }),
      repositoryActivities: [makeActivity({ timestamp: '2026-09-10T23:59:55Z' })],
    }),
  });
  assertEqual(
    'same-repository pull request uses exact publication activity',
    pullRequestFailedPushPublicationTimestamp,
    '2026-09-10T23:59:55Z',
  );

  await reject(
    'same-repository pull request without publication evidence',
    () => resolveFinalizationTimestamp({
      ...base,
      eventName: 'pull_request_target',
      fetchImplementation: makeFixtureFetch({
        current: makeRun({ event: 'pull_request_target' }),
      }),
    }),
    /No exact head publication activity/u,
  );

  const initialPullRequestTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    runHeadRepository: 'fork-owner/repository',
    now: Date.parse('2026-09-11T00:01:00Z'),
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        head_repository: { full_name: 'fork-owner/repository' },
        created_at: '2026-09-11T00:00:05Z',
      }),
      forkActivities: [makeActivity({ timestamp: '2026-09-10T23:59:55Z' })],
    }),
  });
  assertEqual(
    'initial fork pull request preserves the preceding UTC date',
    initialPullRequestTimestamp,
    '2026-09-10T23:59:55Z',
  );

  const reopenedPullRequestTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    runHeadRepository: 'fork-owner/repository',
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        head_repository: { full_name: 'fork-owner/repository' },
      }),
      forkActivities: [makeActivity({
        activity_type: 'force_push',
        timestamp: '2026-09-09T23:59:59Z',
      })],
    }),
  });
  assertEqual(
    'fork force push supplies the exact publication time',
    reopenedPullRequestTimestamp,
    '2026-09-09T23:59:59Z',
  );

  const branchCreationTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    runHeadRepository: 'fork-owner/repository',
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        head_repository: { full_name: 'fork-owner/repository' },
      }),
      forkActivities: [makeActivity({ activity_type: 'branch_creation' })],
    }),
  });
  assertEqual(
    'fork branch creation supplies the exact publication time',
    branchCreationTimestamp,
    '2026-09-10T10:00:00Z',
  );

  const delayedForkTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    runHeadRepository: 'fork-owner/repository',
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        head_repository: { full_name: 'fork-owner/repository' },
      }),
      forkActivities: [makeActivity({ timestamp: '2025-09-10T10:00:00Z' })],
    }),
  });
  assertEqual(
    'fork accepts exact old publication without a client time window',
    delayedForkTimestamp,
    '2025-09-10T10:00:00Z',
  );

  const latestForkPublicationTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    runHeadRepository: 'fork-owner/repository',
    fetchImplementation: makeFixtureFetch({
      current: makeRun({
        event: 'pull_request_target',
        head_repository: { full_name: 'fork-owner/repository' },
      }),
      forkActivities: [
        makeActivity({ id: 11, timestamp: '2026-09-10T11:00:00Z' }),
        makeActivity({ id: 12, timestamp: '2026-09-10T10:00:00Z' }),
      ],
    }),
  });
  assertEqual(
    'fork selects the latest exact publication time',
    latestForkPublicationTimestamp,
    '2026-09-10T11:00:00Z',
  );

  const forkBase = {
    ...base,
    eventName: 'pull_request_target',
    runHeadRepository: 'fork-owner/repository',
  };
  const forkCurrent = makeRun({
    event: 'pull_request_target',
    head_repository: { full_name: 'fork-owner/repository' },
  });
  await reject(
    'missing exact fork publication',
    () => resolveFinalizationTimestamp({
      ...forkBase,
      fetchImplementation: makeFixtureFetch({
        current: forkCurrent,
        forkActivities: [makeActivity({ after: 'c'.repeat(40) })],
      }),
    }),
    /No exact head publication activity/u,
  );
  await reject(
    'malformed fork publication revision',
    () => resolveFinalizationTimestamp({
      ...forkBase,
      fetchImplementation: makeFixtureFetch({
        current: forkCurrent,
        forkActivities: [makeActivity({ before: 'invalid' })],
      }),
    }),
    /malformed revision/u,
  );
  await reject(
    'mismatched fork publication ref',
    () => resolveFinalizationTimestamp({
      ...forkBase,
      fetchImplementation: makeFixtureFetch({
        current: forkCurrent,
        forkActivities: [makeActivity({ ref: 'refs/heads/other' })],
      }),
    }),
    /unexpected identity/u,
  );
  await reject(
    'future fork publication timestamp',
    () => resolveFinalizationTimestamp({
      ...forkBase,
      fetchImplementation: makeFixtureFetch({
        current: forkCurrent,
        forkActivities: [makeActivity({ timestamp: '2026-09-10T12:00:01Z' })],
      }),
    }),
    /repository-activity timestamp.*invalid/u,
  );
  await reject(
    'duplicate fork publication activity',
    () => resolveFinalizationTimestamp({
      ...forkBase,
      fetchImplementation: makeFixtureFetch({
        current: forkCurrent,
        forkActivities: [makeActivity(), makeActivity()],
      }),
    }),
    /contains a duplicate/u,
  );

  const manualActivityTimestamp = await resolveFinalizationTimestamp({
    ...base,
    fetchImplementation: makeFixtureFetch({
      repositoryActivities: [makeActivity({ timestamp: '2026-09-10T09:59:59Z' })],
    }),
  });
  assertEqual(
    'manual event uses exact authenticated repository activity',
    manualActivityTimestamp,
    '2026-09-10T09:59:59Z',
  );

  const manualTagActivityTimestamp = await resolveFinalizationTimestamp({
    ...base,
    runHeadRefName: 'release',
    runHeadRef: 'refs/tags/release',
    fetchImplementation: makeFixtureFetch({
      current: makeRun({ head_branch: 'release' }),
      repositoryActivities: [makeActivity({
        ref: 'refs/tags/release',
        timestamp: '2026-09-10T09:58:58Z',
      })],
      activityRef: 'refs/tags/release',
    }),
  });
  assertEqual(
    'manual tag uses its exact full ref instead of same-name branch history',
    manualTagActivityTimestamp,
    '2026-09-10T09:58:58Z',
  );

  const concurrentManualActivityTimestamp = await resolveFinalizationTimestamp({
    ...base,
    fetchImplementation: makeFixtureFetch({
      repositoryActivities: [
        makeActivity({
          id: 11,
          after: 'b'.repeat(40),
          timestamp: '2026-09-10T12:00:01Z',
        }),
        makeActivity({ id: 12, timestamp: '2026-09-10T09:58:57Z' }),
      ],
    }),
  });
  assertEqual(
    'manual event ignores a newer timestamp on a different revision',
    concurrentManualActivityTimestamp,
    '2026-09-10T09:58:57Z',
  );

  const paginatedActivityTimestamp = await resolveFinalizationTimestamp({
    ...base,
    fetchImplementation: makeFixtureFetch({
      repositoryActivityPages: [
        makeResponse(
          [makeActivity({ after: 'c'.repeat(40) })],
          { link: makeActivityNextLink('owner/repository', 'cursor-1') },
        ),
        makeResponse([makeActivity({ id: 11, timestamp: '2026-09-10T09:58:59Z' })]),
      ],
    }),
  });
  assertEqual(
    'manual event follows a validated activity cursor',
    paginatedActivityTimestamp,
    '2026-09-10T09:58:59Z',
  );

  await reject(
    'cross-origin activity pagination link',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        repositoryActivityPages: [makeResponse(
          [makeActivity({ after: 'c'.repeat(40) })],
          { link: makeActivityNextLink(
            'owner/repository',
            'cursor-1',
            'https://attacker.example',
          ) },
        )],
      }),
    }),
    /pagination link crosses its trust boundary/u,
  );

  const activityOverflowPages = Array.from(
    { length: maximumPageCount },
    (_, index) => makeResponse(
      [makeActivity({ id: 100 + index, after: 'c'.repeat(40) })],
      { link: makeActivityNextLink('owner/repository', `cursor-${index + 1}`) },
    ),
  );
  await reject(
    'activity pagination overflow',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        repositoryActivityPages: activityOverflowPages,
      }),
    }),
    /pagination exceeded 20 pages/u,
  );

  await reject(
    'missing manual publication evidence',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({}),
    }),
    /No exact head publication activity/u,
  );
  await reject(
    'different repository',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        current: makeRun({ repository: { full_name: 'other/repository' } }),
      }),
    }),
    /identity does not match/u,
  );
  await reject(
    'full ref and short name mismatch',
    () => resolveFinalizationTimestamp({
      ...base,
      runHeadRef: 'refs/tags/other',
      fetchImplementation: makeFixtureFetch({}),
    }),
    /full ref does not match its short name/u,
  );
  await reject(
    'current proposed head mismatch',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        current: makeRun({ head_sha: 'b'.repeat(40) }),
      }),
    }),
    /identity does not match/u,
  );
  await reject(
    'current proposed ref mismatch',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        current: makeRun({ head_branch: 'other/branch' }),
      }),
    }),
    /identity does not match/u,
  );

  await reject(
    'future current run',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        current: makeRun({ created_at: '2026-09-10T12:06:01Z' }),
      }),
    }),
    /creation time.*invalid/u,
  );

  console.log(`Finalization resolver self-tests passed: ${fixtures} fixtures.`);
}

async function main() {
  if (process.argv[2] === '--self-test') {
    await runSelfTest();
    return;
  }
  const output = process.env.GITHUB_OUTPUT;
  if (!output) {
    throw new Error('The GitHub output path is unavailable.');
  }
  const timestamp = await resolveFinalizationTimestamp({
    apiUrl: process.env.API_URL,
    repository: process.env.REPOSITORY,
    runId: process.env.RUN_ID,
    runAttempt: process.env.RUN_ATTEMPT,
    eventName: process.env.EVENT_NAME,
    runBaseRevision: process.env.RUN_BASE_REVISION,
    runHeadRevision: process.env.RUN_HEAD_REVISION,
    runHeadRefName: process.env.RUN_HEAD_REF_NAME,
    runHeadRef: process.env.RUN_HEAD_REF,
    runHeadRepository: process.env.RUN_HEAD_REPOSITORY,
    token: process.env.GITHUB_TOKEN,
  });
  appendFileSync(output, `timestamp=${timestamp}\n`, 'utf8');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await main();
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
