// Resolve an authenticated finalization timestamp for agent-document metadata.

import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const objectIdPattern = /^[0-9a-f]{40}$/u;
const positiveIntegerPattern = /^[1-9][0-9]*$/u;
const repositoryPattern = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/u;
const rfc3339UtcPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u;
const maximumPageCount = 20;
const recordsPerPage = 100;
const maximumClockSkewMilliseconds = 300_000;

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
  const createdTime = parseTimestamp(
    activity.timestamp,
    currentCreatedTime,
    'A head repository-activity timestamp',
  );
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
  return { createdAt: activity.timestamp, createdTime };
}

async function readHeadPublication({
  root,
  headRepository,
  headRefName,
  headRevision,
  token,
  fetchImplementation,
  currentCreatedTime,
}) {
  const initialUrl = new URL(`${root}/repos/${headRepository}/activity`);
  initialUrl.searchParams.set('direction', 'desc');
  initialUrl.searchParams.set('per_page', String(recordsPerPage));
  initialUrl.searchParams.set('ref', `refs/heads/${headRefName}`);
  const seenIds = new Set();
  const candidates = [];
  const expected = {
    ref: `refs/heads/${headRefName}`,
    revision: headRevision,
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
  throw new Error(
    'No exact head publication activity matches this revision and ref.',
  );
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

function validateHistoricalRun(run, expected, currentCreatedTime) {
  if (!Number.isSafeInteger(run?.id) || run.id <= 0 ||
      run?.repository?.full_name !== expected.repository ||
      run?.head_repository?.full_name !== expected.headRepository ||
      run?.workflow_id !== expected.workflowId ||
      run?.path !== expected.workflowPath ||
      run?.head_sha !== expected.runHeadRevision ||
      run?.head_branch !== expected.runHeadRefName ||
      run?.event !== expected.eventName ||
      (expected.requireSuccess &&
       (run?.status !== 'completed' || run?.conclusion !== 'success')) ||
      !Number.isSafeInteger(run?.run_attempt) || run.run_attempt <= 0) {
    throw new Error('A historical workflow-run response has an unexpected identity.');
  }
  return parseTimestamp(
    run.created_at,
    currentCreatedTime,
    'A historical workflow-run creation time',
  );
}

async function readHistoricalRuns({
  root,
  repository,
  token,
  fetchImplementation,
  expected,
  currentCreatedTime,
}) {
  const seenIds = new Set();
  const candidates = [];
  let declaredTotal = null;
  for (let page = 1; page <= maximumPageCount; page += 1) {
    const url = new URL(
      `${root}/repos/${repository}/actions/workflows/${expected.workflowId}/runs`,
    );
    url.searchParams.set('branch', expected.runHeadRefName);
    url.searchParams.set('event', expected.eventName);
    if (expected.requireSuccess) {
      url.searchParams.set('status', 'success');
    }
    url.searchParams.set('head_sha', expected.runHeadRevision);
    url.searchParams.set('per_page', String(recordsPerPage));
    url.searchParams.set('page', String(page));
    const pageResponse = await readJson(
      url,
      token,
      fetchImplementation,
      'Historical workflow-run lookup',
    );
    const payload = pageResponse.value;
    if (!Number.isSafeInteger(payload?.total_count) || payload.total_count < 0 ||
        !Array.isArray(payload?.workflow_runs)) {
      throw new Error('The historical workflow-run response is malformed.');
    }
    if (declaredTotal === null) {
      declaredTotal = payload.total_count;
    } else if (declaredTotal !== payload.total_count) {
      throw new Error('The historical workflow-run total changed during pagination.');
    }
    for (const historicalRun of payload.workflow_runs) {
      const createdTime = validateHistoricalRun(
        historicalRun,
        expected,
        currentCreatedTime,
      );
      if (seenIds.has(historicalRun.id)) {
        throw new Error('The historical workflow-run response contains a duplicate run.');
      }
      seenIds.add(historicalRun.id);
      candidates.push({ createdAt: historicalRun.created_at, createdTime });
    }

    const link = pageResponse.headers?.get?.('link') ?? '';
    if (!link.includes('rel="next"')) {
      break;
    }
    if (page === maximumPageCount) {
      throw new Error(
        `Historical workflow-run pagination exceeded ${maximumPageCount} pages.`,
      );
    }
  }

  if (declaredTotal !== seenIds.size) {
    throw new Error('The historical workflow-run response count is incomplete.');
  }
  candidates.sort((left, right) => left.createdTime - right.createdTime);
  return candidates;
}

export async function resolveFinalizationTimestamp({
  apiUrl,
  repository,
  runId,
  runAttempt,
  eventName,
  runHeadRevision,
  runHeadRefName,
  runHeadRepository,
  token,
  now = Date.now(),
  fetchImplementation = globalThis.fetch,
}) {
  if (!apiUrl || !repositoryPattern.test(repository ?? '') ||
      !positiveIntegerPattern.test(runId ?? '') ||
      !positiveIntegerPattern.test(runAttempt ?? '') ||
      !['push', 'pull_request_target', 'workflow_dispatch'].includes(eventName) ||
      !objectIdPattern.test(runHeadRevision ?? '') || !runHeadRefName ||
      !repositoryPattern.test(runHeadRepository ?? '') ||
      /[\u0000\r\n]/u.test(runHeadRefName) || !token ||
      !Number.isFinite(now) || typeof fetchImplementation !== 'function') {
    throw new Error('Trusted workflow-run inputs are unavailable or invalid.');
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
  if (eventName === 'push') {
    return currentRun.created_at;
  }

  if (eventName === 'pull_request_target' && runHeadRepository !== repository) {
    return readHeadPublication({
      root,
      headRepository: runHeadRepository,
      headRefName: runHeadRefName,
      headRevision: runHeadRevision,
      token: null,
      fetchImplementation,
      currentCreatedTime,
    });
  }

  const expectedPush = {
    repository,
    headRepository: repository,
    runHeadRevision,
    runHeadRefName,
    workflowId: currentRun.workflow_id,
    workflowPath: currentRun.path,
    eventName: 'push',
    requireSuccess: true,
  };
  const pushCandidates = await readHistoricalRuns({
    root,
    repository,
    token,
    fetchImplementation,
    expected: expectedPush,
    currentCreatedTime,
  });
  if (pushCandidates.length > 0) {
    return pushCandidates[0].createdAt;
  }
  if (eventName === 'workflow_dispatch') {
    return readHeadPublication({
      root,
      headRepository: repository,
      headRefName: runHeadRefName,
      headRevision: runHeadRevision,
      token,
      fetchImplementation,
      currentCreatedTime,
    });
  }

  const pullRequestCandidates = await readHistoricalRuns({
    root,
    repository,
    token,
    fetchImplementation,
    expected: {
      ...expectedPush,
      headRepository: runHeadRepository,
      eventName: 'pull_request_target',
      requireSuccess: false,
    },
    currentCreatedTime,
  });
  pullRequestCandidates.push({
    createdAt: currentRun.created_at,
    createdTime: currentCreatedTime,
  });
  pullRequestCandidates.sort((left, right) => left.createdTime - right.createdTime);
  return pullRequestCandidates[0].createdAt;
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

function makeHistoricalRun(overrides = {}) {
  return makeRun({
    id: 2,
    event: 'push',
    status: 'completed',
    conclusion: 'success',
    created_at: '2026-09-10T10:00:00Z',
    ...overrides,
  });
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

function makeActivityNextLink(headRepository, cursor, origin = 'https://api.github.example') {
  const url = new URL(`${origin}/api/v3/repos/${headRepository}/activity`);
  url.searchParams.set('direction', 'desc');
  url.searchParams.set('per_page', String(recordsPerPage));
  url.searchParams.set('ref', 'refs/heads/topic/branch');
  url.searchParams.set('after', cursor);
  return `<${url}>; rel="next"`;
}

function makeFixtureFetch({
  current = makeRun(),
  pages = [],
  pullRequestPages = [],
  forkActivities = [],
  repositoryActivities = [],
  forkActivityPages = null,
  repositoryActivityPages = null,
}) {
  return async (request, options) => {
    const url = new URL(String(request));
    if (url.pathname === '/api/v3/repos/fork-owner/repository/activity') {
      if (options?.headers?.Authorization ||
          url.searchParams.get('direction') !== 'desc' ||
          url.searchParams.get('per_page') !== String(recordsPerPage) ||
          url.searchParams.get('ref') !== 'refs/heads/topic/branch' ||
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
          url.searchParams.get('ref') !== 'refs/heads/topic/branch' ||
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
    if (!url.pathname.endsWith('/actions/workflows/99/runs')) {
      return makeResponse({}, { ok: false, status: 404 });
    }
    const event = url.searchParams.get('event');
    if (url.searchParams.get('branch') !== 'topic/branch' ||
        !['push', 'pull_request_target'].includes(event) ||
        (event === 'push' && url.searchParams.get('status') !== 'success') ||
        (event === 'pull_request_target' && url.searchParams.has('status')) ||
        url.searchParams.get('head_sha') !== 'a'.repeat(40) ||
        url.searchParams.get('per_page') !== String(recordsPerPage)) {
      throw new Error('The historical workflow-run query is not exact.');
    }
    const page = Number(url.searchParams.get('page'));
    const selectedPages = event === 'push' ? pages : pullRequestPages;
    return selectedPages[page - 1] ??
      makeResponse({ total_count: 0, workflow_runs: [] });
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
    runHeadRevision: 'a'.repeat(40),
    runHeadRefName: 'topic/branch',
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
    fetchImplementation: makeFixtureFetch({ current: makeRun({ event: 'push' }) }),
  });
  assertEqual('ordinary event uses current run', ordinaryTimestamp, '2026-09-10T12:00:00Z');

  const pullRequestPushTimestamp = await resolveFinalizationTimestamp({
    ...base,
    eventName: 'pull_request_target',
    fetchImplementation: makeFixtureFetch({
      current: makeRun({ event: 'pull_request_target' }),
      pages: [makeResponse({
        total_count: 1,
        workflow_runs: [makeHistoricalRun()],
      })],
    }),
  });
  assertEqual(
    'pull request prefers exact successful push',
    pullRequestPushTimestamp,
    '2026-09-10T10:00:00Z',
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

  const paginatedTimestamp = await resolveFinalizationTimestamp({
    ...base,
    fetchImplementation: makeFixtureFetch({
      pages: [
        makeResponse(
          { total_count: 2, workflow_runs: [makeHistoricalRun()] },
          { link: '<https://api.github.example/page=2>; rel="next"' },
        ),
        makeResponse({
          total_count: 2,
          workflow_runs: [makeHistoricalRun({
            id: 3,
            created_at: '2026-09-09T23:59:59Z',
          })],
        }),
      ],
    }),
  });
  assertEqual(
    'manual event selects earliest eligible run',
    paginatedTimestamp,
    '2026-09-09T23:59:59Z',
  );

  const manualActivityTimestamp = await resolveFinalizationTimestamp({
    ...base,
    fetchImplementation: makeFixtureFetch({
      repositoryActivities: [makeActivity({ timestamp: '2026-09-10T09:59:59Z' })],
    }),
  });
  assertEqual(
    'manual event falls back to exact authenticated repository activity',
    manualActivityTimestamp,
    '2026-09-10T09:59:59Z',
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
      fetchImplementation: makeFixtureFetch({ pages: [] }),
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

  const identityMutations = [
    ['workflow', { workflow_id: 100 }],
    ['head', { head_sha: 'b'.repeat(40) }],
    ['branch', { head_branch: 'other/branch' }],
    ['repository', { repository: { full_name: 'other/repository' } }],
    ['head repository', { head_repository: { full_name: 'other/repository' } }],
    ['event', { event: 'pull_request_target' }],
    ['status', { status: 'in_progress' }],
    ['conclusion', { conclusion: 'failure' }],
  ];
  for (const [name, mutation] of identityMutations) {
    await reject(
      `historical ${name} mismatch`,
      () => resolveFinalizationTimestamp({
        ...base,
        fetchImplementation: makeFixtureFetch({
          pages: [makeResponse({
            total_count: 1,
            workflow_runs: [makeHistoricalRun(mutation)],
          })],
        }),
      }),
      /unexpected identity/u,
    );
  }
  await reject(
    'historical time after dispatch',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        pages: [makeResponse({
          total_count: 1,
          workflow_runs: [makeHistoricalRun({ created_at: '2026-09-10T12:00:01Z' })],
        })],
      }),
    }),
    /creation time.*invalid/u,
  );
  await reject(
    'duplicate historical run',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        pages: [makeResponse({
          total_count: 2,
          workflow_runs: [makeHistoricalRun(), makeHistoricalRun()],
        })],
      }),
    }),
    /duplicate run/u,
  );
  await reject(
    'incomplete historical count',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({
        pages: [makeResponse({ total_count: 2, workflow_runs: [makeHistoricalRun()] })],
      }),
    }),
    /count is incomplete/u,
  );
  const overflowPages = Array.from({ length: maximumPageCount }, (_, index) =>
    makeResponse(
      {
        total_count: maximumPageCount,
        workflow_runs: [makeHistoricalRun({ id: index + 2 })],
      },
      { link: '<https://api.github.example/next>; rel="next"' },
    ));
  await reject(
    'pagination overflow',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({ pages: overflowPages }),
    }),
    /pagination exceeded 20 pages/u,
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
    runHeadRevision: process.env.RUN_HEAD_REVISION,
    runHeadRefName: process.env.RUN_HEAD_REF_NAME,
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
