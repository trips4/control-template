#!/bin/bash

# Read package from environment variable
PACKAGE=$PT_package

# Initialize result variables
STATUS="unknown"
MESSAGE=""
HELD=false

# Check if package argument was provided
if [ -z "$PACKAGE" ]; then
    STATUS="error"
    MESSAGE="No package name provided"
    echo "{\"status\":\"$STATUS\",\"message\":\"$MESSAGE\",\"package\":\"$PACKAGE\",\"held\":$HELD}"
    exit 1
fi

# Hold the package
HOLD_OUTPUT=$(apt-mark hold "$PACKAGE" 2>&1)
HOLD_EXIT_CODE=$?

if [ $HOLD_EXIT_CODE -ne 0 ]; then
    STATUS="error"
    MESSAGE="Failed to hold package: $HOLD_OUTPUT"
    echo "{\"status\":\"$STATUS\",\"message\":\"$MESSAGE\",\"package\":\"$PACKAGE\",\"held\":$HELD}"
    exit 1
fi

# Verify the package is held
if apt-mark showhold | grep -q "^${PACKAGE}$"; then
    STATUS="success"
    MESSAGE="Package $PACKAGE has been successfully held"
    HELD=true
else
    STATUS="error"
    MESSAGE="Package $PACKAGE was not successfully held"
    HELD=false
fi

# Output JSON
echo "{\"status\":\"$STATUS\",\"message\":\"$MESSAGE\",\"package\":\"$PACKAGE\",\"held\":$HELD}"

# Exit with appropriate code
if [ "$STATUS" = "success" ]; then
    exit 0
else
    exit 1
fi