#!/bin/sh
buildNumber=`git rev-list --count main`
echo "CURRENT_PROJECT_VERSION = $buildNumber" > Planet/versioning.xcconfig
echo "Set CURRENT_PROJECT_VERSION to $buildNumber"
git add Planet/versioning.xcconfig
