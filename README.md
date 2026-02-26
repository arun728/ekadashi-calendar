# Ekadashi Calendar app for Android.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## DocAgent Integration

This repository is monitored by [DocAgent](http://localhost:3000) for automatic documentation generation.

When a pull request is merged, DocAgent:
1. Receives the PR webhook from GitHub
2. Fetches the PR diff using the GitHub App installation
3. Calls Claude AI to generate documentation
4. Creates a draft in the DocAgent dashboard for review

### Test PR
This commit tests the end-to-end webhook → AI agent → doc draft pipeline.
