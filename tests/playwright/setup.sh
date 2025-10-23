#!/bin/bash

###############################################################################
# Playwright Test Setup Script
# DoCM Room Reservation System - Automated Test Suite
###############################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  DoCM Room Reservation - Playwright Test Suite Setup          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Node.js is installed
echo -e "${BLUE}[1/4] Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js is not installed!${NC}"
    echo "Please install Node.js 16+ from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v)
echo -e "${GREEN}✓ Node.js installed: ${NODE_VERSION}${NC}"
echo ""

# Install npm dependencies
echo -e "${BLUE}[2/4] Installing npm dependencies...${NC}"
npm install
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
else
    echo -e "${RED}✗ Failed to install dependencies${NC}"
    exit 1
fi
echo ""

# Install Playwright browsers
echo -e "${BLUE}[3/4] Installing Playwright browsers...${NC}"
echo -e "${YELLOW}This may take a few minutes...${NC}"
npx playwright install
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Playwright browsers installed successfully${NC}"
else
    echo -e "${RED}✗ Failed to install browsers${NC}"
    exit 1
fi
echo ""

# Create necessary directories
echo -e "${BLUE}[4/4] Creating test directories...${NC}"
mkdir -p screenshots
mkdir -p test-results
mkdir -p playwright-report
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Verify ColdFusion server
echo -e "${BLUE}Verifying ColdFusion server...${NC}"
if curl -s "http://localhost:8500/DoCMRoomReservation/index.html" > /dev/null; then
    echo -e "${GREEN}✓ ColdFusion server is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Warning: ColdFusion server not accessible at http://localhost:8500${NC}"
    echo -e "${YELLOW}  Please ensure the server is running before executing tests${NC}"
fi
echo ""

# Display next steps
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           ✓ Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Available Test Commands:${NC}"
echo ""
echo -e "  ${YELLOW}npm test${NC}                 - Run all tests"
echo -e "  ${YELLOW}npm run test:ui${NC}          - Interactive test UI"
echo -e "  ${YELLOW}npm run test:headed${NC}      - Watch tests run in browser"
echo -e "  ${YELLOW}npm run test:phase1${NC}      - Run Phase 1 tests only"
echo -e "  ${YELLOW}npm run test:phase2${NC}      - Run Phase 2 tests only"
echo -e "  ${YELLOW}npm run test:phase3${NC}      - Run Phase 3 tests only"
echo -e "  ${YELLOW}npm run test:debug${NC}       - Debug mode"
echo -e "  ${YELLOW}npm run test:report${NC}      - View test report"
echo ""
echo -e "${BLUE}Test Coverage:${NC}"
echo -e "  ✓ Phase 1: Improved Time Selection, Email Notifications, Meeting Titles"
echo -e "  ✓ Phase 2: Edit Reservations, Calendar Views, Filtering & Search"
echo -e "  ✓ Phase 3: Recurring Reservations with Full UI"
echo -e "  ✓ Total: 27 automated end-to-end tests"
echo ""
echo -e "${GREEN}Ready to run tests!${NC}"
echo -e "Execute: ${YELLOW}npm test${NC}"
echo ""
