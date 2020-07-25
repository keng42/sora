flutter build ios

cd release
rm -rf ./Payload
mkdir -p ./Payload
cp -r ../build/ios/iphoneos/Runner.app Payload/Runner.app 
zip -r Sora.v.ipa Payload
rm -rf ./Payload

cd ..
