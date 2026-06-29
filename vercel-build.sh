#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting Vercel build for Flutter Web..."

# Install Flutter if not already present
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter stable channel..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Configuring Flutter for web..."
flutter config --enable-web
flutter config --no-analytics

echo "Building Flutter web app..."
flutter build web --release

echo "Copying build to public directory for Vercel..."
mkdir -p public
cp -r build/web/* public/

echo "Build complete!"
