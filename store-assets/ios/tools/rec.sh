#!/bin/zsh
# Record one video test from outside the app: rec.sh testV1Free
S=$SCRATCH
PM=1FCB139D-9322-408E-9167-4AE3655A4F0A
T=$1
mkdir -p $S/shots/video
cd $S/devshots/ios-native
# Build first so recording starts close to the test's launch.
xcodebuild build-for-testing -project EkadashiCalendar.xcodeproj -scheme EkadashiCalendar \
  -destination "id=$PM" -derivedDataPath $S/dd-shots -quiet > $S/shots/video/$T.build.log 2>&1 || { echo "BUILD FAILED"; exit 1; }
xcrun simctl io $PM recordVideo --codec=h264 --force $S/shots/video/$T.mov > $S/shots/video/$T.rec.log 2>&1 &
REC=$!
sleep 1.5
python3 -c 'import time;print(time.time())' > $S/shots/video/$T.start
TEST_RUNNER_SHOTS_DIR=$S/shots/raw xcodebuild test-without-building -project EkadashiCalendar.xcodeproj -scheme EkadashiCalendar \
  -destination "id=$PM" -derivedDataPath $S/dd-shots -only-testing:EkadashiCalendarUITests/StoreShotsUITests/$T \
  > $S/shots/video/$T.log 2>&1
kill -INT $REC; wait $REC
grep -E "^MARK|MARK " $S/shots/video/$T.log | sed 's/.*MARK /MARK /' > $S/shots/video/$T.marks
grep -E "MISSING|error:|Test Case.*(passed|failed)" $S/shots/video/$T.log | cut -c1-250
echo "done $T"
