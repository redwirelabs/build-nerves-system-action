# Build Nerves System Action

A simple GitHub Action for building your Nerves systems.

## Usage

### Outputs

* `artifact_filename`: The generated artifact’s file name.
  * You can find it in the job workspace under `.br2`, or download it using the `download-artifact` action.

### Example cache workflow

```yaml
name: IoT Gate IMX8PLUS

on: push

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4
    - uses: redwirelabs/build-nerves-system-action@v1
      id: nerves
    - name: Create draft release
      shell: bash
      working-directory: ${{ github.workspace }}/.br2
      run: |
        gh release \
          create \
            ${{ github.ref_name }} \
            ${{ steps.nerves.outputs.artifact_filename }} \
          --title ${{ github.ref_name }} \
          --draft
```
