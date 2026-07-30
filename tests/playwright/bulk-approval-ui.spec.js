/**
 * Browser verification for the bulk-approval selection UI (Requirement 5) and the
 * mobile usability criterion (Requirement 2).
 *
 * SAFETY: this suite never confirms an approval -- not the Bulk Approve dialog and
 * not the single-approve dialog. A live SMTP relay is configured, so completing one
 * would send real notifications. Every assertion is about selection state, dialog
 * content and layout, all of which happen in the browser before anything is
 * submitted; each dialog is explicitly cancelled.
 *
 * Authentication is client-side sessionStorage in this application, so the tests
 * seed it directly rather than driving a login form.
 *
 * Fixtures are created and removed through tests/ui-fixture.cfm.
 *
 * Run:
 *   npx playwright test bulk-approval-ui.spec.js --config=playwright.config.js
 */
const { test, expect } = require('@playwright/test');

const BASE = 'http://localhost:8500/DoCMRoomReservation';
const APPROVALS = `${BASE}/booking_approvals.html`;
const FIXTURE = `${BASE}/tests/ui-fixture.cfm`;
const SEED_COUNT = 55;
// Actual pending total is reported by the fixture (it also seeds one
// booked-on-behalf row), so this is read rather than assumed.
let SEEDED_PENDING = SEED_COUNT;

// Populate the sessionStorage the pages expect before any page script runs.
async function authenticateAsAdmin(page) {
  await page.addInitScript(() => {
    sessionStorage.setItem('ISLOGGINEDIN', 'true');
    sessionStorage.setItem('ROLE', 'Site Admin');
    sessionStorage.setItem('ROLEID', '1');
    sessionStorage.setItem('USER_ID', '76');
    sessionStorage.setItem('EMPLID', '999999');
    sessionStorage.setItem('NAME', 'Playwright Admin');
    sessionStorage.setItem('EMAIL', 'playwright@example.invalid');
    sessionStorage.setItem('AUTHORIZED_USER', 'true');
  });
}

// The grid is a DataTable populated over AJAX; wait for real rows.
async function waitForGrid(page) {
  await page.waitForSelector('#bookingsTableBody tr', { timeout: 30000 });
  await expect
    .poll(async () => page.locator('#bookingsTableBody tr').count(), { timeout: 30000 })
    .toBeGreaterThan(1);
}

test.beforeAll(async ({ request }) => {
  const res = await request.get(`${FIXTURE}?mode=seed&count=${SEED_COUNT}`);
  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  expect(body.OK).toBeTruthy();
  SEEDED_PENDING = Number(body.SEEDEDPENDING);
  expect(SEEDED_PENDING).toBeGreaterThanOrEqual(50);
});

test.afterAll(async ({ request }) => {
  const res = await request.get(`${FIXTURE}?mode=clean`);
  const body = await res.json();
  // Leaving fixtures behind would pollute the pending queue.
  expect(body.MARKEDROWSNOW).toBe(0);
});

test.beforeEach(async ({ page }) => {
  await authenticateAsAdmin(page);
});

test('bulk action bar is hidden until something is selected', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  await expect(page.locator('#bulkActionBar')).toBeHidden();

  await page.locator('.bookingSelect').first().check();

  await expect(page.locator('#bulkActionBar')).toBeVisible();
  await expect(page.locator('#selectedCountLabel')).toHaveText('1 selected');
});

test('only pending rows offer a checkbox', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  // Show every row on one page so eligibility can be counted directly.
  await page.selectOption('select[name="bookingsTable_length"]', '100').catch(() => {});
  await page.waitForTimeout(500);

  const rows = page.locator('#bookingsTableBody tr');
  const rowCount = await rows.count();
  expect(rowCount).toBeGreaterThan(0);

  for (let i = 0; i < rowCount; i++) {
    const row = rows.nth(i);
    const statusText = ((await row.locator('td').nth(8).innerText()) || '').trim().toLowerCase();
    const hasCheckbox = (await row.locator('input.bookingSelect').count()) > 0;
    if (statusText === 'pending') {
      expect(hasCheckbox, `pending row ${i} should be selectable`).toBe(true);
    } else {
      expect(hasCheckbox, `row ${i} with status "${statusText}" must not be selectable`).toBe(false);
    }
  }
});

test('select-all covers every eligible row across pages, not just the visible page', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  await page.locator('#selectAllBookings').check();

  // Selection is tracked outside the DOM, so the count reflects the whole
  // filtered result set even though only one page is rendered.
  await expect(page.locator('#selectedCountLabel')).toHaveText(`${SEEDED_PENDING} selected`);

  const visibleCheckboxes = await page.locator('.bookingSelect').count();
  expect(visibleCheckboxes).toBeLessThan(SEEDED_PENDING);
});

test('select-all applies only to eligible rows in the current filtered result set', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  // Filter by one row's exact request number. DataTables uses "smart" search
  // that splits on whitespace and matches terms in any order, so a single
  // numeric token is the reliable way to narrow to a known-small set.
  const targetId = (
    await page.locator('#bookingsTableBody tr').first().locator('td').nth(1).innerText()
  ).trim();
  await page.fill('input[type="search"]', targetId);
  await page.waitForTimeout(900);

  // Render the whole filtered set on one page so eligible rows can be counted
  // directly from the DOM rather than inferred.
  await page.selectOption('.dt-length select, select[name="bookingsTable_length"]', '100').catch(() => {});
  await page.waitForTimeout(600);

  const eligibleInFilter = await page.locator('.bookingSelect').count();
  expect(eligibleInFilter).toBeGreaterThan(0);
  expect(eligibleInFilter, 'the filter must actually narrow the result set').toBeLessThan(SEEDED_PENDING);

  await page.locator('#selectAllBookings').check();

  // The criterion: select-all covers exactly the eligible rows in the filtered
  // set -- no more (would include filtered-out rows) and no fewer.
  await expect(page.locator('#selectedCountLabel')).toHaveText(
    eligibleInFilter === 1 ? '1 selected' : `${eligibleInFilter} selected`
  );

  // Clearing the filter must not retroactively pull in the rest.
  await page.fill('input[type="search"]', '');
  await page.waitForTimeout(900);
  await expect(page.locator('#selectedCountLabel')).toHaveText(
    eligibleInFilter === 1 ? '1 selected' : `${eligibleInFilter} selected`
  );
});

test('selection survives paging', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  const first = page.locator('.bookingSelect').first();
  await first.check();
  const value = await first.getAttribute('value');
  await expect(page.locator('#selectedCountLabel')).toHaveText('1 selected');

  // DataTables 2.x renders the clickable control as button.page-link inside an
  // li.dt-paging-button; the li itself is not clickable.
  await page.click('button.page-link.next');
  await page.waitForTimeout(800);
  await expect(page.locator('#selectedCountLabel')).toHaveText('1 selected');

  // Returning to page one must show the box still ticked.
  await page.click('button.page-link.previous');
  await page.waitForTimeout(800);
  await expect(page.locator(`.bookingSelect[value="${value}"]`)).toBeChecked();
});

test('clear selection empties the count and hides the bar', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  await page.locator('#selectAllBookings').check();
  await expect(page.locator('#bulkActionBar')).toBeVisible();

  await page.click('#clearSelectionBtn');
  await expect(page.locator('#bulkActionBar')).toBeHidden();
  await expect(page.locator('#selectAllBookings')).not.toBeChecked();
});

test('stays responsive selecting more than 50 requests', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  const start = Date.now();
  await page.locator('#selectAllBookings').check();
  await expect(page.locator('#selectedCountLabel')).toHaveText(`${SEEDED_PENDING} selected`);
  const elapsed = Date.now() - start;

  // Generous ceiling: this is a smoke check against an O(n^2) regression, not a
  // benchmark. The acceptance criterion is 50+ selected requests.
  expect(SEEDED_PENDING).toBeGreaterThanOrEqual(50);
  expect(elapsed, `select-all of ${SEEDED_PENDING} rows took ${elapsed}ms`).toBeLessThan(5000);
});

test('confirmation dialog appears and can be dismissed without approving anything', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  await page.locator('.bookingSelect').first().check();
  await page.click('#bulkApproveBtn');

  const dialog = page.locator('.swal2-popup');
  await expect(dialog).toBeVisible();
  await expect(dialog).toContainText(/Approve 1 request\?/i);

  // Cancel deliberately: confirming would send a real approval notification.
  await page.click('.swal2-cancel');
  await expect(dialog).toBeHidden();

  // Nothing was submitted, so the selection is intact.
  await expect(page.locator('#selectedCountLabel')).toHaveText('1 selected');
});

test('user-supplied text in the grid is escaped, not rendered as markup', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  // No fixture injects markup, but a stray element from the meeting-title cell
  // would show up here if escaping regressed.
  const injected = await page.locator('#bookingsTableBody script, #bookingsTableBody img[onerror]').count();
  expect(injected).toBe(0);
});

test('remains usable at a mobile viewport with no horizontal page overflow', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(APPROVALS);
  await waitForGrid(page);

  await page.locator('.bookingSelect').first().check();
  await expect(page.locator('#bulkActionBar')).toBeVisible();
  await expect(page.locator('#bulkApproveBtn')).toBeVisible();

  // The wide table must scroll inside its own container rather than forcing the
  // document to scroll sideways.
  const overflow = await page.evaluate(() =>
    document.documentElement.scrollWidth - document.documentElement.clientWidth
  );
  expect(overflow, `document overflows horizontally by ${overflow}px`).toBeLessThanOrEqual(2);
});

test('approver confirmation shows Requested By and Reservation For, escaped', async ({ page }) => {
  await page.goto(APPROVALS);
  await waitForGrid(page);

  // Find the row booked on someone else's behalf.
  await page.fill('input[type="search"]', 'onbehalf marker');
  await page.waitForTimeout(900);

  const row = page.locator('#bookingsTableBody tr').first();
  await expect(row).toBeVisible();

  // On narrow viewports DataTables' responsive mode collapses the Actions column
  // into an expandable child row, so the approve control is not directly
  // clickable. Expand the row first -- the flow is still reachable on mobile, it
  // just takes one extra tap.
  let approveBtn = row.locator('.approveBtn');
  if (!(await approveBtn.isVisible().catch(() => false))) {
    const expander = row.locator('td.dtr-control, td.dtr-control-expand, .dtr-control').first();
    if (await expander.count()) {
      await expander.click();
      await page.waitForTimeout(500);
    }
    approveBtn = page.locator('.approveBtn:visible').first();
  }
  await approveBtn.click();

  const dialog = page.locator('.swal2-popup');
  await expect(dialog).toBeVisible();
  await expect(dialog).toContainText('Approve Booking Request?');

  // Both names must be present and distinguishable.
  await expect(dialog).toContainText('Requested By:');
  await expect(dialog).toContainText('Reservation For:');
  await expect(dialog).toContainText('Dr Onbehalf');
  await expect(dialog).toContainText('Haematology');

  // The seeded name contains markup; it must be rendered as text, not executed.
  const injected = await dialog.locator('script').count();
  expect(injected).toBe(0);
  await expect(dialog).toContainText('<script>alert(1)</script>');

  // Cancel: confirming would approve for real and notify the requester.
  await page.click('.swal2-cancel');
  await expect(dialog).toBeHidden();
});
