/**
 * Verifies direct-link support (Requirement 1: "Link to view the request").
 * Notification emails link to index.html?bookingId=N; the parameter was
 * previously ignored, so the link only opened the dashboard.
 *
 * Read-only: opens a details dialog. Nothing is approved or cancelled, so no
 * notification is generated.
 */
const { test, expect } = require('@playwright/test');

const BASE = 'http://localhost:8500/DoCMRoomReservation';
const FIXTURE = `${BASE}/tests/ui-fixture.cfm`;

async function authenticateAsAdmin(page) {
  await page.addInitScript(() => {
    sessionStorage.setItem('ISLOGGINEDIN', 'true');
    sessionStorage.setItem('ROLE', 'Site Admin');
    sessionStorage.setItem('USER_ID', '76');
    sessionStorage.setItem('EMPLID', '999999');
    sessionStorage.setItem('AUTHORIZED_USER', 'true');
  });
}

let targetId;

test.beforeAll(async ({ request }) => {
  const res = await request.get(`${FIXTURE}?mode=seed&count=3`);
  expect(res.ok()).toBeTruthy();
  expect((await res.json()).OK).toBeTruthy();
  // Resolve a real request number to link to.
  const list = await request.get(`${BASE}/assets/cfc/approvals.cfc?method=getPendingBookings`);
  const body = await list.json();
  expect(body.SUCCESS).toBeTruthy();
  expect(body.DATA.length).toBeGreaterThan(0);
  targetId = body.DATA[0].ID;
});

test.afterAll(async ({ request }) => {
  const res = await request.get(`${FIXTURE}?mode=clean`);
  expect((await res.json()).MARKEDROWSNOW).toBe(0);
});

test.beforeEach(async ({ page }) => { await authenticateAsAdmin(page); });

test('?bookingId=N opens that reservation and shows its stored details', async ({ page }) => {
  await page.goto(`${BASE}/index.html?bookingId=${targetId}`);

  const dialog = page.locator('.swal2-popup');
  await expect(dialog).toBeVisible({ timeout: 20000 });
  await expect(dialog).toContainText(`Request #${targetId}`);

  // Wait for the detail fetch to replace the loading row.
  await expect(dialog).toContainText('Request Number', { timeout: 20000 });
  await expect(dialog).toContainText('Requested By');
  await expect(dialog).toContainText('Status');
  // The value shown must be the reservation that was asked for.
  await expect(dialog).toContainText(String(targetId));
});

test('the bookingId parameter is removed so a refresh does not reopen it', async ({ page }) => {
  await page.goto(`${BASE}/index.html?bookingId=${targetId}`);
  await expect(page.locator('.swal2-popup')).toBeVisible({ timeout: 20000 });
  await expect.poll(() => page.url()).not.toContain('bookingId');
});

test('an unknown request number degrades gracefully instead of erroring', async ({ page }) => {
  await page.goto(`${BASE}/index.html?bookingId=99999999`);
  const dialog = page.locator('.swal2-popup');
  await expect(dialog).toBeVisible({ timeout: 20000 });
  await expect(dialog).toContainText(/unavailable|could not be loaded/i, { timeout: 20000 });
});

test('a non-numeric bookingId is ignored and no dialog opens', async ({ page }) => {
  await page.goto(`${BASE}/index.html?bookingId=abc%27%22%3Cscript%3E`);
  // Give the page time to settle; nothing should open.
  await page.waitForTimeout(3000);
  await expect(page.locator('.swal2-popup')).toHaveCount(0);
});
