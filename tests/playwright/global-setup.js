/**
 * Global Setup for Playwright Tests
 * Creates necessary directories for test artifacts
 */

const fs = require('fs');
const path = require('path');

async function globalSetup() {
  // Create screenshots directory if it doesn't exist
  const screenshotsDir = path.join(__dirname, 'screenshots');
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
    console.log('Created screenshots directory:', screenshotsDir);
  }

  // Create test-results directory if it doesn't exist
  const testResultsDir = path.join(__dirname, 'test-results');
  if (!fs.existsSync(testResultsDir)) {
    fs.mkdirSync(testResultsDir, { recursive: true });
    console.log('Created test-results directory:', testResultsDir);
  }

  console.log('✅ Global setup completed');
}

module.exports = globalSetup;
