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
  const response = await fetchImplementation(url, {
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
    },
  });
  if (!response?.ok) {
    throw new Error(`${displayName} failed: ${response?.status ?? 'unknown'}.`);
  }
  return {
    headers: response.headers,
    value: await response.json(),
  };
}

function validateCurrentRun(run, expected) {
  if (String(run?.id) !== expected.runId ||
      run?.repository?.full_name !== expected.repository ||
      run?.head_repository?.full_name !== expected.repository ||
      run?.head_sha !== expected.trustedRevision ||
      run?.head_branch !== expected.refName ||
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
      run?.head_repository?.full_name !== expected.repository ||
      run?.workflow_id !== expected.workflowId ||
      run?.path !== expected.workflowPath ||
      run?.head_sha !== expected.trustedRevision ||
      run?.head_branch !== expected.refName ||
      run?.event !== 'push' || run?.status !== 'completed' ||
      run?.conclusion !== 'success' ||
      !Number.isSafeInteger(run?.run_attempt) || run.run_attempt <= 0) {
    throw new Error('A historical workflow-run response has an unexpected identity.');
  }
  return parseTimestamp(
    run.created_at,
    currentCreatedTime,
    'A historical workflow-run creation time',
  );
}

export async function resolveFinalizationTimestamp({
  apiUrl,
  repository,
  runId,
  runAttempt,
  eventName,
  trustedRevision,
  refName,
  token,
  now = Date.now(),
  fetchImplementation = globalThis.fetch,
}) {
  if (!apiUrl || !repositoryPattern.test(repository ?? '') ||
      !positiveIntegerPattern.test(runId ?? '') ||
      !positiveIntegerPattern.test(runAttempt ?? '') || !eventName ||
      !objectIdPattern.test(trustedRevision ?? '') || !refName ||
      /[\u0000\r\n]/u.test(refName) || !token ||
      !Number.isFinite(now) || typeof fetchImplementation !== 'function') {
    throw new Error('Trusted workflow-run inputs are unavailable or invalid.');
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
    trustedRevision,
    refName,
    eventName,
  };
  validateCurrentRun(currentRun, expectedCurrent);
  const currentCreatedTime = parseTimestamp(
    currentRun.created_at,
    now + maximumClockSkewMilliseconds,
    'The workflow-run creation time',
  );
  if (eventName !== 'workflow_dispatch') {
    return currentRun.created_at;
  }

  const expectedHistorical = {
    repository,
    trustedRevision,
    refName,
    workflowId: currentRun.workflow_id,
    workflowPath: currentRun.path,
  };
  const seenIds = new Set();
  const candidates = [];
  let declaredTotal = null;
  for (let page = 1; page <= maximumPageCount; page += 1) {
    const url = new URL(
      `${root}/repos/${repository}/actions/workflows/${currentRun.workflow_id}/runs`,
    );
    url.searchParams.set('branch', refName);
    url.searchParams.set('event', 'push');
    url.searchParams.set('status', 'success');
    url.searchParams.set('head_sha', trustedRevision);
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
        expectedHistorical,
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
  if (candidates.length === 0) {
    throw new Error(
      'No successful non-manual workflow run matches this workflow, revision, and ref.',
    );
  }
  candidates.sort((left, right) => left.createdTime - right.createdTime);
  return candidates[0].createdAt;
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

function makeFixtureFetch({ current = makeRun(), pages = [] }) {
  return async (request) => {
    const url = new URL(String(request));
    if (!url.pathname.startsWith('/api/v3/repos/owner/repository/')) {
      throw new Error('The API base path was not preserved.');
    }
    if (url.pathname.endsWith('/actions/runs/1')) {
      return makeResponse(current);
    }
    if (!url.pathname.endsWith('/actions/workflows/99/runs')) {
      return makeResponse({}, { ok: false, status: 404 });
    }
    if (url.searchParams.get('branch') !== 'topic/branch' ||
        url.searchParams.get('event') !== 'push' ||
        url.searchParams.get('status') !== 'success' ||
        url.searchParams.get('head_sha') !== 'a'.repeat(40) ||
        url.searchParams.get('per_page') !== String(recordsPerPage)) {
      throw new Error('The historical workflow-run query is not exact.');
    }
    const page = Number(url.searchParams.get('page'));
    return pages[page - 1] ?? makeResponse({ total_count: 0, workflow_runs: [] });
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
    trustedRevision: 'a'.repeat(40),
    refName: 'topic/branch',
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

  await reject(
    'missing historical run',
    () => resolveFinalizationTimestamp({
      ...base,
      fetchImplementation: makeFixtureFetch({ pages: [] }),
    }),
    /No successful non-manual workflow run/u,
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
    trustedRevision: process.env.TRUSTED_REVISION,
    refName: process.env.REF_NAME,
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
