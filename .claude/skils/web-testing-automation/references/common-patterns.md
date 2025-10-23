# Common Playwright Test Patterns

## Table of Contents
1. [Form Testing Patterns](#form-testing-patterns)
2. [Authentication Patterns](#authentication-patterns)
3. [Data Table Patterns](#data-table-patterns)
4. [Modal Dialog Patterns](#modal-dialog-patterns)
5. [Drag and Drop Patterns](#drag-and-drop-patterns)
6. [File Upload Patterns](#file-upload-patterns)
7. [Infinite Scroll Patterns](#infinite-scroll-patterns)
8. [Custom Wait Patterns](#custom-wait-patterns)

## Form Testing Patterns

### Basic Form Submission
```typescript
test('submit contact form', async ({ page }) => {
  await page.goto('/contact');
  
  await page.fill('[name="name"]', 'John Doe');
  await page.fill('[name="email"]', 'john@example.com');
  await page.fill('[name="message"]', 'Test message');
  await page.selectOption('[name="subject"]', 'Support');
  await page.check('[name="subscribe"]');
  
  await page.click('button[type="submit"]');
  
  await expect(page.locator('.success-message')).toBeVisible();
});
```

### Form Validation Testing
```typescript
test('validate required fields', async ({ page }) => {
  await page.goto('/contact');
  await page.click('button[type="submit"]');
  
  // Check HTML5 validation
  const nameInput = page.locator('[name="name"]');
  await expect(nameInput).toHaveAttribute('required');
  
  // Check for custom validation messages
  await expect(page.locator('.error')).toContainText('Name is required');
});
```

### Multi-Step Form
```typescript
test('complete multi-step form', async ({ page }) => {
  await page.goto('/registration');
  
  // Step 1: Personal Info
  await page.fill('[name="firstName"]', 'John');
  await page.fill('[name="lastName"]', 'Doe');
  await page.click('button:has-text("Next")');
  
  // Step 2: Contact Info
  await expect(page.locator('.step-2')).toBeVisible();
  await page.fill('[name="email"]', 'john@example.com');
  await page.fill('[name="phone"]', '555-1234');
  await page.click('button:has-text("Next")');
  
  // Step 3: Review and Submit
  await expect(page.locator('.step-3')).toBeVisible();
  await expect(page.locator('.review')).toContainText('John Doe');
  await page.click('button:has-text("Submit")');
  
  await expect(page).toHaveURL(/.*success/);
});
```

## Authentication Patterns

### Login with Session Storage
```typescript
test('login and persist session', async ({ page, context }) => {
  await page.goto('/login');
  await page.fill('#email', 'user@example.com');
  await page.fill('#password', 'password123');
  await page.click('button[type="submit"]');
  
  await expect(page).toHaveURL(/.*dashboard/);
  
  // Save session state
  await context.storageState({ path: 'auth.json' });
});

test.use({ storageState: 'auth.json' });

test('access protected page', async ({ page }) => {
  // Already authenticated from saved session
  await page.goto('/dashboard');
  await expect(page.locator('.user-profile')).toBeVisible();
});
```

### JWT Token Authentication
```typescript
test('authenticate with JWT', async ({ page, context }) => {
  // Get token from API
  const response = await page.request.post('/api/auth/login', {
    data: {
      email: 'user@example.com',
      password: 'password123'
    }
  });
  
  const { token } = await response.json();
  
  // Set token in localStorage
  await context.addInitScript((token) => {
    localStorage.setItem('authToken', token);
  }, token);
  
  await page.goto('/dashboard');
  await expect(page.locator('.user-menu')).toBeVisible();
});
```

## Data Table Patterns

### Sorting Table Columns
```typescript
test('sort table by column', async ({ page }) => {
  await page.goto('/users');
  
  // Get initial first row
  const firstRowBefore = await page.locator('tbody tr').first().textContent();
  
  // Click sort header
  await page.click('th:has-text("Name")');
  
  // Wait for re-render
  await page.waitForTimeout(500);
  
  const firstRowAfter = await page.locator('tbody tr').first().textContent();
  
  expect(firstRowBefore).not.toBe(firstRowAfter);
});
```

### Filtering Table Data
```typescript
test('filter table data', async ({ page }) => {
  await page.goto('/products');
  
  const rowsBeforeFilter = await page.locator('tbody tr').count();
  
  await page.fill('[name="search"]', 'laptop');
  await page.waitForSelector('tbody tr');
  
  const rowsAfterFilter = await page.locator('tbody tr').count();
  
  expect(rowsAfterFilter).toBeLessThan(rowsBeforeFilter);
  
  // Verify filtered results contain search term
  const allRows = await page.locator('tbody tr').all();
  for (const row of allRows) {
    const text = await row.textContent();
    expect(text?.toLowerCase()).toContain('laptop');
  }
});
```

### Pagination
```typescript
test('paginate through table', async ({ page }) => {
  await page.goto('/users');
  
  // Get first page first user
  const firstPageUser = await page.locator('tbody tr').first().textContent();
  
  // Go to next page
  await page.click('button:has-text("Next")');
  await page.waitForSelector('tbody tr');
  
  // Get second page first user
  const secondPageUser = await page.locator('tbody tr').first().textContent();
  
  expect(firstPageUser).not.toBe(secondPageUser);
  
  // Verify page indicator updated
  await expect(page.locator('.page-indicator')).toContainText('Page 2');
});
```

## Modal Dialog Patterns

### Open and Close Modal
```typescript
test('open and close modal', async ({ page }) => {
  await page.goto('/');
  
  // Modal should not be visible initially
  await expect(page.locator('.modal')).not.toBeVisible();
  
  // Open modal
  await page.click('button:has-text("Open Modal")');
  await expect(page.locator('.modal')).toBeVisible();
  
  // Close modal
  await page.click('.modal .close-button');
  await expect(page.locator('.modal')).not.toBeVisible();
});
```

### Modal with Form Submission
```typescript
test('submit form in modal', async ({ page }) => {
  await page.goto('/users');
  
  await page.click('button:has-text("Add User")');
  await expect(page.locator('.modal')).toBeVisible();
  
  await page.fill('.modal [name="name"]', 'New User');
  await page.fill('.modal [name="email"]', 'new@example.com');
  await page.click('.modal button[type="submit"]');
  
  // Wait for modal to close
  await expect(page.locator('.modal')).not.toBeVisible();
  
  // Verify user was added
  await expect(page.locator('tbody')).toContainText('New User');
});
```

## Drag and Drop Patterns

### Simple Drag and Drop
```typescript
test('drag and drop element', async ({ page }) => {
  await page.goto('/kanban');
  
  const source = page.locator('[data-task="task-1"]');
  const target = page.locator('[data-column="done"]');
  
  await source.dragTo(target);
  
  // Verify element moved
  await expect(target.locator('[data-task="task-1"]')).toBeVisible();
});
```

### File Upload via Drag and Drop
```typescript
test('upload file via drag and drop', async ({ page }) => {
  await page.goto('/upload');
  
  // Create file input listener
  const [fileChooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    page.click('.dropzone')
  ]);
  
  await fileChooser.setFiles('path/to/file.pdf');
  
  await expect(page.locator('.file-name')).toContainText('file.pdf');
});
```

## File Upload Patterns

### Single File Upload
```typescript
test('upload single file', async ({ page }) => {
  await page.goto('/upload');
  
  const fileInput = page.locator('input[type="file"]');
  await fileInput.setInputFiles('tests/fixtures/test-file.pdf');
  
  await page.click('button:has-text("Upload")');
  
  await expect(page.locator('.success')).toContainText('File uploaded');
});
```

### Multiple File Upload
```typescript
test('upload multiple files', async ({ page }) => {
  await page.goto('/upload');
  
  await page.setInputFiles('input[type="file"]', [
    'tests/fixtures/file1.pdf',
    'tests/fixtures/file2.pdf',
    'tests/fixtures/file3.pdf'
  ]);
  
  // Verify all files are listed
  const fileList = page.locator('.file-list li');
  await expect(fileList).toHaveCount(3);
});
```

## Infinite Scroll Patterns

### Load More on Scroll
```typescript
test('infinite scroll loading', async ({ page }) => {
  await page.goto('/feed');
  
  // Get initial count
  const initialCount = await page.locator('.post').count();
  
  // Scroll to bottom
  await page.evaluate(() => {
    window.scrollTo(0, document.body.scrollHeight);
  });
  
  // Wait for new items to load
  await page.waitForFunction(
    (count) => document.querySelectorAll('.post').length > count,
    initialCount
  );
  
  const finalCount = await page.locator('.post').count();
  expect(finalCount).toBeGreaterThan(initialCount);
});
```

### Load All Items
```typescript
test('load all infinite scroll items', async ({ page }) => {
  await page.goto('/feed');
  
  let previousCount = 0;
  let currentCount = await page.locator('.post').count();
  
  // Keep scrolling until no more items load
  while (currentCount > previousCount) {
    previousCount = currentCount;
    
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });
    
    await page.waitForTimeout(1000); // Wait for load
    currentCount = await page.locator('.post').count();
  }
  
  console.log(`Loaded ${currentCount} total items`);
});
```

## Custom Wait Patterns

### Wait for API Call
```typescript
test('wait for specific API call', async ({ page }) => {
  await page.goto('/dashboard');
  
  // Wait for specific API response
  const responsePromise = page.waitForResponse(
    response => response.url().includes('/api/stats') && response.status() === 200
  );
  
  await page.click('button:has-text("Refresh")');
  
  const response = await responsePromise;
  const data = await response.json();
  
  expect(data).toHaveProperty('totalUsers');
});
```

### Wait for Network Idle
```typescript
test('wait for all requests to complete', async ({ page }) => {
  await page.goto('/dashboard');
  
  await page.click('button:has-text("Load Data")');
  
  // Wait until network is idle (no requests for 500ms)
  await page.waitForLoadState('networkidle');
  
  // Now safe to check loaded data
  await expect(page.locator('.data-loaded')).toBeVisible();
});
```

### Wait for Element State Change
```typescript
test('wait for element to be enabled', async ({ page }) => {
  await page.goto('/form');
  
  const submitButton = page.locator('button[type="submit"]');
  
  // Button starts disabled
  await expect(submitButton).toBeDisabled();
  
  // Fill required field
  await page.fill('[name="email"]', 'test@example.com');
  
  // Wait for button to be enabled
  await expect(submitButton).toBeEnabled();
  
  await submitButton.click();
});
```

### Custom Polling
```typescript
test('wait for custom condition', async ({ page }) => {
  await page.goto('/processing');
  
  await page.click('button:has-text("Start Process")');
  
  // Poll for completion
  await page.waitForFunction(() => {
    const status = document.querySelector('.status')?.textContent;
    return status === 'Complete';
  }, { timeout: 30000 });
  
  await expect(page.locator('.status')).toHaveText('Complete');
});
```

## Advanced Selector Patterns

### Chaining Selectors
```typescript
// Find button inside specific card
await page.locator('.card').filter({ hasText: 'Product 1' })
  .locator('button:has-text("Add to Cart")').click();

// Find row with specific data
await page.locator('tr').filter({ 
  has: page.locator('td:has-text("John Doe")') 
}).locator('button.edit').click();
```

### Dynamic Selectors
```typescript
test('click dynamic element', async ({ page }) => {
  const userId = 123;
  await page.click(`[data-user-id="${userId}"] button.delete`);
  
  // Or with template
  const selector = (id: number) => `[data-user-id="${id}"] button.delete`;
  await page.click(selector(userId));
});
```

### Text-Based Selectors
```typescript
// Exact match
await page.click('button:has-text("Submit")');

// Partial match
await page.locator('div:has-text("Welcome")').first().click();

// Case-insensitive
await page.click('button:text-is("submit")');

// Regex
await page.click('button:text-matches("^Submit|Save$")');
```
