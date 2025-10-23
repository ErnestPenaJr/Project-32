#!/usr/bin/env python3
"""
Playwright Test Project Initializer
Creates a complete Playwright testing project structure with best practices.
"""

import os
import sys
import json
import subprocess
from pathlib import Path

def create_directory(path):
    """Create directory if it doesn't exist."""
    Path(path).mkdir(parents=True, exist_ok=True)
    print(f"✅ Created directory: {path}")

def create_file(path, content):
    """Create file with content."""
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ Created file: {path}")

def init_playwright_project(project_name, base_url="http://localhost:8500"):
    """Initialize a complete Playwright testing project.
    
    Default base_url is set to http://localhost:8500 (ColdFusion).
    Common ports:
    - ColdFusion: http://localhost:8500
    - React: http://localhost:51xx (e.g., 5100)
    - PHP: http://localhost:4000
    """
    
    print(f"\n🚀 Initializing Playwright project: {project_name}\n")
    
    # Create project directory
    project_dir = Path(project_name)
    if project_dir.exists():
        response = input(f"Directory '{project_name}' already exists. Continue? (y/n): ")
        if response.lower() != 'y':
            print("❌ Aborted")
            return
    
    create_directory(project_dir)
    os.chdir(project_dir)
    
    # Initialize npm project
    print("\n📦 Initializing npm project...")
    package_json = {
        "name": project_name,
        "version": "1.0.0",
        "description": "Automated testing with Playwright",
        "scripts": {
            "test": "playwright test",
            "test:headed": "playwright test --headed",
            "test:debug": "playwright test --debug",
            "test:ui": "playwright test --ui",
            "test:chromium": "playwright test --project=chromium",
            "test:firefox": "playwright test --project=firefox",
            "test:webkit": "playwright test --project=webkit",
            "report": "playwright show-report",
            "codegen": "playwright codegen"
        },
        "devDependencies": {
            "@playwright/test": "^1.40.0",
            "@axe-core/playwright": "^4.8.0"
        }
    }
    
    create_file("package.json", json.dumps(package_json, indent=2))
    
    # Create playwright config
    config_content = f'''import {{ defineConfig, devices }} from '@playwright/test';

export default defineConfig({{
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  
  reporter: [
    ['html'],
    ['json', {{ outputFile: 'test-results/results.json' }}],
    ['junit', {{ outputFile: 'test-results/junit.xml' }}]
  ],
  
  use: {{
    baseURL: '{base_url}',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 30000,
  }},

  projects: [
    {{
      name: 'chromium',
      use: {{ ...devices['Desktop Chrome'] }},
    }},
    {{
      name: 'firefox',
      use: {{ ...devices['Desktop Firefox'] }},
    }},
    {{
      name: 'webkit',
      use: {{ ...devices['Desktop Safari'] }},
    }},
    {{
      name: 'Mobile Chrome',
      use: {{ ...devices['Pixel 5'] }},
    }},
    {{
      name: 'Mobile Safari',
      use: {{ ...devices['iPhone 12'] }},
    }},
  ],
}});
'''
    create_file("playwright.config.ts", config_content)
    
    # Create directory structure
    directories = [
        "tests/auth",
        "tests/e2e",
        "tests/api",
        "pages",
        "fixtures",
        "utils",
        "screenshots",
        "test-results"
    ]
    
    for dir_path in directories:
        create_directory(dir_path)
    
    # Create BasePage
    base_page_content = '''import { Page } from '@playwright/test';

export class BasePage {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async navigate(path: string) {
    await this.page.goto(path);
  }

  async waitForPageLoad() {
    await this.page.waitForLoadState('networkidle');
  }

  async takeScreenshot(name: string) {
    await this.page.screenshot({ path: `screenshots/${name}.png` });
  }

  async fillField(locator: string, value: string) {
    await this.page.fill(locator, value);
  }

  async clickButton(locator: string) {
    await this.page.click(locator);
  }

  async getText(locator: string): Promise<string> {
    return await this.page.textContent(locator) || '';
  }

  async waitForElement(locator: string, timeout: number = 5000) {
    await this.page.waitForSelector(locator, { timeout });
  }

  async isVisible(locator: string): Promise<boolean> {
    return await this.page.isVisible(locator);
  }
}
'''
    create_file("pages/BasePage.ts", base_page_content)
    
    # Create example test
    example_test_content = '''import { test, expect } from '@playwright/test';

test.describe('Example Tests', () => {
  test('homepage loads successfully', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/./); // Has any title
  });

  test('navigation works', async ({ page }) => {
    await page.goto('/');
    
    // Example: Click a navigation link
    // await page.click('a:has-text("About")');
    // await expect(page).toHaveURL(/.*about/);
  });
});
'''
    create_file("tests/example.spec.ts", example_test_content)
    
    # Create test data fixtures
    test_data_content = '''{
  "users": {
    "validUser": {
      "email": "test@example.com",
      "password": "TestPassword123!",
      "name": "Test User"
    },
    "adminUser": {
      "email": "admin@example.com",
      "password": "AdminPass123!",
      "name": "Admin User"
    }
  },
  "testData": {
    "sampleText": "This is test data",
    "sampleNumber": 42
  }
}
'''
    create_file("fixtures/test-data.json", test_data_content)
    
    # Create .gitignore
    gitignore_content = '''node_modules/
test-results/
playwright-report/
playwright/.cache/
screenshots/
*.log
.env
auth.json
'''
    create_file(".gitignore", gitignore_content)
    
    # Create README
    readme_content = f'''# {project_name}

Automated testing with Playwright

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Install Playwright browsers:
   ```bash
   npx playwright install
   ```

## Running Tests

```bash
# Run all tests
npm test

# Run in headed mode (see browser)
npm run test:headed

# Run in debug mode
npm run test:debug

# Run UI mode (interactive)
npm run test:ui

# Run specific browser
npm run test:chromium

# View test report
npm run report
```

## Project Structure

- `tests/` - Test files organized by feature
- `pages/` - Page Object Models
- `fixtures/` - Test data
- `utils/` - Helper utilities
- `playwright.config.ts` - Playwright configuration

## Writing Tests

See `tests/example.spec.ts` for examples.

## CI/CD

Tests are configured to run in CI with appropriate retries and parallel execution.
'''
    create_file("README.md", readme_content)
    
    print(f"\n✅ Playwright project '{project_name}' initialized successfully!")
    print(f"\n📝 Next steps:")
    print(f"   1. cd {project_name}")
    print(f"   2. npm install")
    print(f"   3. npx playwright install")
    print(f"   4. npm test")
    print(f"\n💡 Start writing tests in the tests/ directory")
    print(f"💡 Use 'npx playwright codegen' to generate test code\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python init_playwright.py <project-name> [base-url]")
        print("\nExamples:")
        print("  ColdFusion: python init_playwright.py my-cf-tests http://localhost:8500")
        print("  React:      python init_playwright.py my-react-tests http://localhost:5100")
        print("  PHP:        python init_playwright.py my-php-tests http://localhost:4000")
        print("\nDefault base URL: http://localhost:8500")
        sys.exit(1)
    
    project_name = sys.argv[1]
    base_url = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8500"
    
    init_playwright_project(project_name, base_url)
