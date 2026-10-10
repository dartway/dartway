import 'dart:convert';

import '../project_layout.dart';

/// Image builds after the required CI workflow succeeds, including PR dry runs.
String kamalImagesWorkflow(
  ProjectLayout layout,
  List<String> services,
  String imageRepository,
) {
  final matrix = [
    for (final service in services)
      {
        'service': service,
        'dockerfile': switch (service) {
          'api' => '${layout.serverPackage}/Dockerfile',
          'web' => '${layout.flutterPackage}/Dockerfile',
          _ => 'deploy/kamal/storage/Dockerfile',
        },
        'context': service == 'storage' ? 'deploy/kamal/storage' : '.',
      },
  ];
  return _workflow
      .replaceAll('__MATRIX__', jsonEncode(matrix))
      .replaceAll('__IMAGE_REPOSITORY__', imageRepository);
}

const _workflow = r'''name: Images

on:
  workflow_run:
    workflows: [CI]
    types: [completed]

# Serialize retries of the same SHA so two runs cannot push it twice.
concurrency:
  group: images-${{ github.event.workflow_run.head_sha }}
  cancel-in-progress: false

permissions:
  contents: read
  packages: write

jobs:
  images:
    if: >-
      github.event.workflow_run.conclusion == 'success' &&
      github.event.workflow_run.head_repository.full_name == github.repository &&
      (github.event.workflow_run.event == 'pull_request' ||
       github.event.workflow_run.head_branch == 'master' ||
       github.event.workflow_run.head_branch == 'release')
    name: images / ${{ matrix.service }}
    runs-on: ${{ fromJSON(vars.DW_CI_RUNS_ON || '"ubuntu-latest"') }}
    timeout-minutes: 45
    strategy:
      fail-fast: false
      matrix:
        include: __MATRIX__
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_sha }}
          persist-credentials: false

      - name: Deployment configured
        id: deployment
        run: |
          if [ -f deploy/studio.yml ]; then
            echo "configured=true" >> "$GITHUB_OUTPUT"
          fi

      - uses: docker/setup-buildx-action@v3
        if: steps.deployment.outputs.configured == 'true'

      - name: Registry login
        if: steps.deployment.outputs.configured == 'true' && github.event.workflow_run.event == 'push'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Image identity and immutable tag
        id: image
        if: steps.deployment.outputs.configured == 'true'
        env:
          SERVICE: ${{ matrix.service }}
          REPOSITORY: __IMAGE_REPOSITORY__
          SHA: ${{ github.event.workflow_run.head_sha }}
          PUBLISH: ${{ github.event.workflow_run.event == 'push' && (github.event.workflow_run.head_branch == 'master' || github.event.workflow_run.head_branch == 'release') }}
        run: |
          tag="ghcr.io/${REPOSITORY}-${SERVICE}:${SHA}"
          echo "tag=$tag" >> "$GITHUB_OUTPUT"
          echo "publish=$PUBLISH" >> "$GITHUB_OUTPUT"
          if [ "$PUBLISH" = true ]; then
            if docker buildx imagetools inspect "$tag" > manifest.txt 2>&1; then
              echo "Image already exists; skipping $tag"
              echo "exists=true" >> "$GITHUB_OUTPUT"
            elif ! grep -Eiq 'manifest unknown|not found|404' manifest.txt; then
              cat manifest.txt
              exit 1
            fi
          fi

      - name: Build once, push on master and release
        if: steps.deployment.outputs.configured == 'true' && steps.image.outputs.exists != 'true'
        uses: docker/build-push-action@v6
        with:
          context: ${{ matrix.context }}
          file: ${{ matrix.dockerfile }}
          platforms: linux/amd64
          push: ${{ steps.image.outputs.publish == 'true' }}
          tags: ${{ steps.image.outputs.tag }}
          labels: org.opencontainers.image.source=https://github.com/${{ github.repository }}
          cache-from: type=gha,scope=${{ matrix.service }}
          cache-to: ${{ steps.image.outputs.publish == 'true' && format('type=gha,mode=max,scope={0}', matrix.service) || '' }}
''';
